import json
import logging
import os
import time
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secretsmanager = boto3.client("secretsmanager")
ecs = boto3.client("ecs")
codedeploy = boto3.client("codedeploy")
s3 = boto3.client("s3")


def _load_json_env(name: str) -> list[dict[str, Any]]:
    raw_value = os.getenv(name, "[]")
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in env var {name}: {exc}") from exc

    if not isinstance(parsed, list):
        raise ValueError(f"Env var {name} must be a JSON list")

    return parsed


def _extract_password(secret_string: str) -> str:
    try:
        parsed = json.loads(secret_string)
    except json.JSONDecodeError as exc:
        raise ValueError("RDS secret payload must be valid JSON") from exc

    if isinstance(parsed, dict):
        value = parsed.get("password")
        if isinstance(value, str) and value:
            return value

    raise ValueError("Unable to extract 'password' from rotated secret payload")


def _get_secret_string(secret_arn: str) -> str:
    response = secretsmanager.get_secret_value(SecretId=secret_arn)

    secret_string = response.get("SecretString")
    if not secret_string:
        raise ValueError(f"Secret {secret_arn} does not contain SecretString")

    return secret_string


def _sync_runtime_secret(
    runtime_secret_arn: str, runtime_secret_key: str, new_password: str
) -> None:
    logger.info(
        "Syncing rotated password into consolidated runtime secret: secret=%s key=%s",
        runtime_secret_arn,
        runtime_secret_key,
    )

    current_secret_string = _get_secret_string(runtime_secret_arn)
    try:
        payload = json.loads(current_secret_string)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"Consolidated runtime secret must be JSON. secret={runtime_secret_arn}"
        ) from exc

    if not isinstance(payload, dict):
        raise ValueError("Consolidated runtime secret payload must be a JSON object")

    existing_password = payload.get(runtime_secret_key)
    if existing_password == new_password:
        logger.info(
            "Runtime secret already has current password. Skipping PutSecretValue."
        )
        return

    payload[runtime_secret_key] = new_password

    secretsmanager.put_secret_value(
        SecretId=runtime_secret_arn,
        SecretString=json.dumps(payload, separators=(",", ":")),
    )
    logger.info("Runtime secret synced successfully")


def _rollout_ecs(targets: list[dict[str, Any]]) -> list[dict[str, str]]:
    if not targets:
        raise ValueError(
            "ECS_TARGETS_JSON is empty while rollout_mode=ecs_force_new_deployment"
        )

    results = []
    for target in targets:
        cluster_name = target.get("cluster_name")
        service_name = target.get("service_name")

        if not cluster_name or not service_name:
            raise ValueError(f"Invalid ECS target: {target}")

        logger.info(
            "Forcing ECS deployment: cluster=%s service=%s",
            cluster_name,
            service_name,
        )
        ecs.update_service(
            cluster=cluster_name,
            service=service_name,
            forceNewDeployment=True,
        )
        results.append({"cluster_name": cluster_name, "service_name": service_name})

    return results


def _rollout_codedeploy(
    targets: list[dict[str, Any]], trigger_id: str
) -> list[dict[str, str]]:
    results = []
    for target in targets:
        application_name = target.get("application_name")
        deployment_group_name = target.get("deployment_group_name")
        s3_bucket = target.get("s3_bucket")
        s3_key = target.get("s3_key")
        fallback_s3_key = target.get("fallback_s3_key", "appspec.yaml")
        bundle_type = target.get("bundle_type", "yaml")

        if not all([application_name, deployment_group_name, s3_bucket, s3_key]):
            raise ValueError(f"Invalid CodeDeploy target: {target}")

        selected_key = s3_key
        try:
            s3.head_object(Bucket=s3_bucket, Key=s3_key)
            logger.info("Using primary AppSpec key: s3://%s/%s", s3_bucket, s3_key)
        except ClientError as exc:
            error_code = exc.response.get("Error", {}).get("Code", "")
            if error_code in {"404", "NoSuchKey", "NotFound"}:
                logger.warning(
                    "Primary AppSpec key not found (s3://%s/%s). Falling back to s3://%s/%s",
                    s3_bucket,
                    s3_key,
                    s3_bucket,
                    fallback_s3_key,
                )
                selected_key = fallback_s3_key
                try:
                    s3.head_object(Bucket=s3_bucket, Key=selected_key)
                except ClientError as fallback_exc:
                    fallback_code = fallback_exc.response.get("Error", {}).get(
                        "Code", ""
                    )
                    if fallback_code in {"404", "NoSuchKey", "NotFound"}:
                        raise ValueError(
                            f"Neither primary key '{s3_key}' nor fallback key "
                            f"'{fallback_s3_key}' found in bucket '{s3_bucket}'"
                        ) from fallback_exc
                    raise
            else:
                raise

        # AWS API expects YAML/JSON uppercase, tar/tgz/zip lowercase
        bundle_type_normalized = (
            bundle_type.upper()
            if bundle_type.lower() in ("yaml", "json")
            else bundle_type.lower()
        )

        logger.info(
            "Creating CodeDeploy deployment: app=%s dg=%s s3=%s/%s bundle_type=%s",
            application_name,
            deployment_group_name,
            s3_bucket,
            selected_key,
            bundle_type_normalized,
        )

        response = codedeploy.create_deployment(
            applicationName=application_name,
            deploymentGroupName=deployment_group_name,
            revision={
                "revisionType": "S3",
                "s3Location": {
                    "bucket": s3_bucket,
                    "key": selected_key,
                    "bundleType": bundle_type_normalized,
                },
            },
            description=f"Secrets rotation rollout trigger={trigger_id}",
        )

        deployment_id = response.get("deploymentId", "unknown")
        logger.info("CodeDeploy deployment created: deployment_id=%s", deployment_id)

        results.append(
            {
                "application_name": application_name,
                "deployment_group_name": deployment_group_name,
                "deployment_id": deployment_id,
            }
        )

    return results


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    logger.info("Received event: %s", json.dumps(event))

    expected_secret_arn = os.environ["RDS_PASSWORD_SECRET_ARN"]
    runtime_secret_arn = os.getenv("SYNC_RUNTIME_SECRET_ARN")
    runtime_secret_key = os.getenv("SYNC_RUNTIME_SECRET_KEY", "postgres_password")
    rollout_mode = os.getenv("ROLLOUT_MODE", "ecs_force_new_deployment")
    delay_seconds = int(os.getenv("DELAY_SECONDS", "30"))

    resources = event.get("resources", [])
    event_source = event.get("source")
    detail_type = event.get("detail-type")
    detail = event.get("detail", {}) if isinstance(event.get("detail"), dict) else {}

    if event_source != "aws.secretsmanager":
        logger.warning("Ignoring event with source=%s", event_source)
        return {"status": "ignored", "reason": "unsupported-source"}

    is_native_rotation_succeeded = detail_type == "Rotation Succeeded"
    is_cloudtrail_rotation_succeeded = (
        detail.get("eventSource") == "secretsmanager.amazonaws.com"
        and detail.get("eventName") == "RotationSucceeded"
    )
    is_cloudtrail_promote_awscurrent = (
        detail.get("eventSource") == "secretsmanager.amazonaws.com"
        and detail.get("eventName") == "UpdateSecretVersionStage"
        and isinstance(detail.get("requestParameters"), dict)
        and detail.get("requestParameters", {}).get("versionStage") == "AWSCURRENT"
    )

    if (
        not is_native_rotation_succeeded
        and not is_cloudtrail_rotation_succeeded
        and not is_cloudtrail_promote_awscurrent
    ):
        logger.warning(
            "Ignoring event with detail-type=%s detail=%s", detail_type, detail
        )
        return {"status": "ignored", "reason": "unsupported-detail-type"}

    if is_native_rotation_succeeded:
        if expected_secret_arn not in resources:
            logger.warning(
                "Ignoring native event due to secret mismatch. expected=%s resources=%s",
                expected_secret_arn,
                resources,
            )
            return {"status": "ignored", "reason": "secret-mismatch"}

    if is_cloudtrail_rotation_succeeded:
        secret_id = (
            detail.get("additionalEventData", {}).get("SecretId")
            if isinstance(detail.get("additionalEventData"), dict)
            else None
        )
        if secret_id != expected_secret_arn:
            logger.warning(
                "Ignoring CloudTrail event due to secret mismatch. expected=%s secret_id=%s",
                expected_secret_arn,
                secret_id,
            )
            return {"status": "ignored", "reason": "secret-mismatch"}

    if is_cloudtrail_promote_awscurrent:
        secret_id = detail.get("requestParameters", {}).get("secretId")
        if secret_id != expected_secret_arn:
            logger.warning(
                "Ignoring UpdateSecretVersionStage event due to secret mismatch. expected=%s secret_id=%s",
                expected_secret_arn,
                secret_id,
            )
            return {"status": "ignored", "reason": "secret-mismatch"}

    trigger_id = str(event.get("id", "unknown-event-id"))
    logger.info(
        "Validated rotation completion event for secret=%s trigger_id=%s",
        expected_secret_arn,
        trigger_id,
    )

    logger.info(
        "Rotation detected. Waiting %s seconds before rollout...", delay_seconds
    )
    time.sleep(delay_seconds)

    try:
        rotated_secret_string = _get_secret_string(expected_secret_arn)
        rotated_password = _extract_password(rotated_secret_string)

        if runtime_secret_arn:
            _sync_runtime_secret(
                runtime_secret_arn, runtime_secret_key, rotated_password
            )

        if rollout_mode == "ecs_force_new_deployment":
            logger.info("Starting ECS force new deployment rollout")
            ecs_targets = _load_json_env("ECS_TARGETS_JSON")
            rollout_results = _rollout_ecs(ecs_targets)
        elif rollout_mode == "codedeploy_s3_appspec":
            logger.info("Starting CodeDeploy rollout using S3 AppSpec revision")
            codedeploy_targets = _load_json_env("CODEDEPLOY_TARGETS_JSON")
            rollout_results = _rollout_codedeploy(codedeploy_targets, trigger_id)
        else:
            raise ValueError(f"Unsupported rollout mode: {rollout_mode}")

        logger.info("Rotation rollout completed successfully")
        return {
            "status": "ok",
            "rollout_mode": rollout_mode,
            "targets": rollout_results,
            "trigger_id": trigger_id,
        }

    except (ClientError, ValueError, TypeError) as exc:
        logger.exception("Rotation rollout failed: %s", exc)
        raise
