# sts_credential_vending

Least-privilege STS credential-vending chain for an on-prem host reaching a private AWS VPC over
Site-to-Site VPN. It implements the two-hop pattern:

1. A **bootstrap IAM user** — the host's only long-lived identity — whose *only* permission is
   `sts:AssumeRole` on the access role. No data-plane access of its own.
2. An **access IAM role**, trusted exclusively by that bootstrap user, whose inline policy can:
   - `secretsmanager:GetSecretValue` on **one** secret (`db_secret_arn`), and
   - (optionally) `rds-db:connect` for **one** RDS IAM database user — minting short-lived
     RDS IAM-auth tokens, so no long-lived DB password is needed on the host.

Optionally emits a programmatic access key for the bootstrap user (lab convenience).

> This module **replaces the library `iam_role`** for this use case. The library module only
> supports a service-principal trust and managed-policy ARNs; here we need an **AWS-principal trust**
> (the bootstrap user) plus a tightly scoped **inline** policy built from
> `aws_iam_policy_document`.

## Usage

```hcl
module "credential_vending" {
  source = "../../modules/sts_credential_vending"

  app_name       = "s2s-vpn-lab"
  aws_region     = "ap-southeast-1"
  aws_account_id = data.aws_caller_identity.current.account_id

  db_secret_arn = module.aurora_postgresql.master_secret_arn

  # RDS IAM-auth token vending (default on)
  enable_rds_iam_connect = true
  rds_resource_id        = module.aurora_postgresql.cluster_resource_id
  iam_db_username        = "app_iam"

  # Lab convenience — see SECURITY NOTE
  create_access_key    = true
  max_session_duration = 3600

  tags = var.tags
}
```

On the host, the flow is: use the bootstrap access key to `aws sts assume-role` the access role,
then with those temporary creds either `aws secretsmanager get-secret-value` or
`aws rds generate-db-auth-token`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | string | (required) | Name prefix for every resource and the Name tag. |
| `bootstrap_user_name` | string | `null` | Bootstrap user name; defaults to `${app_name}-bootstrap`. |
| `access_role_name` | string | `null` | Access role name; defaults to `${app_name}-access-role`. |
| `db_secret_arn` | string | (required) | The one Secrets Manager secret ARN the access role may read. |
| `enable_rds_iam_connect` | bool | `true` | Add `rds-db:connect` for one DB user. |
| `rds_resource_id` | string | `""` | Aurora `cluster_resource_id`; required when `enable_rds_iam_connect`. |
| `iam_db_username` | string | `"app_iam"` | DB user name in the `rds-db:connect` ARN. |
| `aws_region` | string | (required) | Region used to build the `rds-db` ARN. |
| `aws_account_id` | string | (required) | 12-digit account ID used to build the `rds-db` ARN. |
| `create_access_key` | bool | `true` | Emit a programmatic access key for the bootstrap user. |
| `max_session_duration` | number | `3600` | Access-role max session seconds (3600–43200). |
| `tags` | map(string) | `{}` | Extra tags merged onto taggable resources. |

When `enable_rds_iam_connect = true`, a `precondition` on the access role policy fails the plan/apply
if `rds_resource_id` is empty.

## Outputs

| Name | Sensitive | Description |
|------|-----------|-------------|
| `bootstrap_user_name` | no | Bootstrap IAM user name. |
| `bootstrap_user_arn` | no | Bootstrap IAM user ARN. |
| `access_role_arn` | no | Access role ARN (pass as `RoleArn` to `sts:AssumeRole`). |
| `access_role_name` | no | Access role name. |
| `bootstrap_access_key_id` | yes | Access key ID, or `null` when `create_access_key = false`. |
| `bootstrap_secret_access_key` | yes | Secret access key, or `null` when `create_access_key = false`. |

## SECURITY NOTE

When `create_access_key = true`, the IAM **secret access key is written into Terraform state in
cleartext** (and surfaces as a `sensitive` output). This is acceptable **only** for a throwaway lab
whose state lives in an SSE-KMS-encrypted, versioned, access-restricted S3 backend.

For anything beyond this lab, set `create_access_key = false` and provision the bootstrap
credential out-of-band (e.g. IAM Identity Center, an externally created/rotated access key, or — best
— skip the long-lived user entirely and use IAM Roles Anywhere / an instance or SSM identity). The
module's role + policies are designed to work unchanged with an externally supplied bootstrap
credential.
