data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda" {
  name = "${var.app_name}-rds-rotation-rollout-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.app_name}-rds-rotation-rollout-lambda-role"
  })
}

locals {
  enable_runtime_secret_sync = var.sync_runtime_secret_arn != null && var.sync_runtime_secret_arn != ""

  ecs_service_arns = [
    for target in var.ecs_targets : "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${target.cluster_name}/${target.service_name}"
  ]

  codedeploy_application_arns = [
    for target in var.codedeploy_targets : "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:application:${target.application_name}"
  ]

  codedeploy_deployment_group_arns = [
    for target in var.codedeploy_targets : "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:${target.application_name}/${target.deployment_group_name}"
  ]

  codedeploy_bucket_arns = [
    for target in var.codedeploy_targets : "arn:aws:s3:::${target.s3_bucket}"
  ]

  codedeploy_object_arns = [
    for target in var.codedeploy_targets : "arn:aws:s3:::${target.s3_bucket}/${target.s3_key}"
  ]

  codedeploy_fallback_object_arns = [
    for target in var.codedeploy_targets : "arn:aws:s3:::${target.s3_bucket}/${target.fallback_s3_key}"
  ]
}

resource "aws_iam_policy" "lambda" {
  name = "${var.app_name}-rds-rotation-rollout-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for statement in [
        {
          Sid    = "AllowCloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          Sid    = "AllowReadRotatedRdsSecret"
          Effect = "Allow"
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:ListSecretVersionIds"
          ]
          Resource = var.rds_password_secret_arn
        },
        var.rollout_mode == "ecs_force_new_deployment" ? {
          Sid    = "AllowEcsRollout"
          Effect = "Allow"
          Action = [
            "ecs:DescribeServices",
            "ecs:UpdateService"
          ]
          Resource = local.ecs_service_arns
        } : null,
        var.rollout_mode == "codedeploy_s3_appspec" ? {
          Sid    = "AllowCodeDeployManageTargets"
          Effect = "Allow"
          Action = [
            "codedeploy:CreateDeployment",
            "codedeploy:RegisterApplicationRevision",
            "codedeploy:GetDeploymentGroup",
            "codedeploy:GetApplication"
          ]
          Resource = concat(local.codedeploy_application_arns, local.codedeploy_deployment_group_arns)
        } : null,
        var.rollout_mode == "codedeploy_s3_appspec" ? {
          Sid    = "AllowCodeDeployReadDeployments"
          Effect = "Allow"
          Action = [
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig"
          ]
          # Resource "*" is required because:
          # - GetDeployment needs deployment ARNs that don't exist at plan time
          # - GetDeploymentConfig references AWS predefined configs (e.g. CodeDeployDefault.ECSAllAtOnce)
          #   whose ARNs are account-specific and not tied to our app/dg
          # Both are read-only actions, so wildcard scope is acceptable.
          Resource = "*"
        } : null,
        var.rollout_mode == "codedeploy_s3_appspec" ? {
          Sid    = "AllowReadAppspecFromS3"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket"
          ]
          Resource = concat(local.codedeploy_bucket_arns, local.codedeploy_object_arns, local.codedeploy_fallback_object_arns)
        } : null,
        local.enable_runtime_secret_sync ? {
          Sid    = "AllowSyncConsolidatedRuntimeSecret"
          Effect = "Allow"
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:PutSecretValue",
            "secretsmanager:ListSecretVersionIds"
          ]
          Resource = var.sync_runtime_secret_arn
        } : null
      ] : statement if statement != null
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.app_name}-rds-rotation-rollout-lambda-policy"
  })
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

module "rotation_rollout_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "=8.1.2"

  function_name = "${var.app_name}-rds-rotation-rollout"
  description   = "Trigger rollout after Secrets Manager RDS password rotation"
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_size

  source_path     = "${path.module}/lambda"
  build_in_docker = false

  create_role = false
  lambda_role = aws_iam_role.lambda.arn

  cloudwatch_logs_retention_in_days = var.log_retention_in_days

  environment_variables = {
    RDS_PASSWORD_SECRET_ARN = var.rds_password_secret_arn
    ROLLOUT_MODE            = var.rollout_mode
    DELAY_SECONDS           = tostring(var.delay_seconds)
    ECS_TARGETS_JSON = jsonencode([
      for target in var.ecs_targets : {
        cluster_name = target.cluster_name
        service_name = target.service_name
      }
    ])
    CODEDEPLOY_TARGETS_JSON = jsonencode([
      for target in var.codedeploy_targets : {
        application_name      = target.application_name
        deployment_group_name = target.deployment_group_name
        s3_bucket             = target.s3_bucket
        s3_key                = target.s3_key
        fallback_s3_key       = target.fallback_s3_key
        bundle_type           = target.bundle_type
      }
    ])
    SYNC_RUNTIME_SECRET_ARN = local.enable_runtime_secret_sync ? var.sync_runtime_secret_arn : ""
    SYNC_RUNTIME_SECRET_KEY = var.sync_runtime_secret_key
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-rds-rotation-rollout"
  })
}

resource "aws_cloudwatch_event_rule" "rotation_succeeded" {
  name        = "${var.app_name}-rds-password-rotation-succeeded"
  description = "Trigger rollout when Secrets Manager promotes rotated version to AWSCURRENT"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = ["UpdateSecretVersionStage"]
      requestParameters = {
        secretId     = [var.rds_password_secret_arn]
        versionStage = ["AWSCURRENT"]
      }
    }
  })

  tags = merge(var.tags, {
    Name = "${var.app_name}-rds-password-rotation-succeeded"
  })
}

resource "aws_cloudwatch_event_target" "rotation_succeeded_lambda" {
  rule      = aws_cloudwatch_event_rule.rotation_succeeded.name
  target_id = "rotation-rollout-lambda"
  arn       = module.rotation_rollout_lambda.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.rotation_rollout_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rotation_succeeded.arn
}
