# AWS RDS Unified Terraform Module

Terraform module to provision an RDS primary instance with optional read replica, networking, monitoring, and credential management.

## Features

- RDS primary instance (PostgreSQL, MySQL, MariaDB)
- Optional read replica
- DB subnet group (create new or use existing)
- Security group with restricted ingress from allowed security groups
- Parameter group with default PostgreSQL tuning + custom parameters
- Secrets Manager credential secret (JSON format)
- Enhanced monitoring IAM role (optional)
- Performance Insights (optional)
- PostgreSQL S3 import/export IAM integration (optional)

## Credential Secret Format

When `db_password` is empty, this module generates a password and stores credentials in Secrets Manager as JSON:

```json
{
  "engine": "postgres",
  "host": "<db-hostname>",
  "username": "dbadmin",
  "password": "<generated-password>",
  "dbname": "clinic",
  "port": "5432"
}
```

The secret version has `ignore_changes = [secret_string, version_stages]` — Terraform will not overwrite the secret after Secrets Manager rotation promotes a new version to `AWSCURRENT`.

The RDS instance itself also has `ignore_changes = [password]` — so subsequent `terraform apply` runs will not reset the password back to the original generated value.

---

## Usage

### Example 1: Development (Cost Optimized)

```terraform
module "rds" {
  source = "../../modules/rds"

  app_name = "${var.environment}-${var.app_name}"
  db_name  = "${var.environment}-${var.app_name}-db"
  vpc_id   = module.vpc.vpc_id

  db_subnet_group_name = module.vpc.database_subnet_group_name
  availability_zone    = "${var.region}${var.azs_name[0]}"

  engine         = "postgres"
  engine_version = "18.1"
  engine_family  = "postgres18"
  instance_class = "db.t4g.micro"

  db_database = "clinic"
  db_username = "dbadmin"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  restricted_security_group_ids = [aws_security_group.ecs_tasks.id]

  skip_final_snapshot    = true
  deletion_protection    = false
  monitoring_interval    = 0
  create_parameter_group = true

  tags = local.tags
}
```

### Example 2: Production Baseline

```terraform
module "rds" {
  source = "../../modules/rds"

  app_name = "${var.environment}-${var.app_name}"
  db_name  = "${var.environment}-${var.app_name}-db"
  vpc_id   = module.vpc.vpc_id

  db_subnet_group_name = module.vpc.database_subnet_group_name
  availability_zone    = "${var.region}${var.azs_name[0]}"

  engine         = "postgres"
  engine_version = "18.1"
  engine_family  = "postgres18"
  instance_class = "db.t4g.small"

  db_database = "clinic"
  db_username = "dbadmin"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  backup_retention_period   = 7
  backup_window             = "18:00-19:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-${var.app_name}-db-final-snapshot"
  deletion_protection       = true

  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  restricted_security_group_ids = [aws_security_group.ecs_tasks.id]

  tags = local.tags
}
```

---

## Password Rotation Architecture

This module integrates with two companion modules to implement fully automated, zero-downtime password rotation:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Stage 1 — modules/rds_secret_rotation                                      │
│  AWS SAR Lambda (SecretsManagerRDSPostgreSQLRotationSingleUser)              │
│  Triggered by Secrets Manager schedule                                       │
│                                                                              │
│  Flow:  createSecret → setSecret (DB password changed) → testSecret         │
│         → finishSecret (AWSCURRENT promoted to new version)                 │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ Secrets Manager promotes AWSCURRENT
                               │ → EventBridge receives UpdateSecretVersionStage
                               │   via CloudTrail
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Stage 2 — modules/rds_rotation_rollout                                     │
│  Lambda triggered by EventBridge (CloudTrail: UpdateSecretVersionStage)     │
│                                                                              │
│  Flow:  Validate event → sleep(delay_seconds) → read new password           │
│         → sync runtime secret (optional) → trigger rollout                  │
│                                                                              │
│  Rollout mode A — codedeploy_s3_appspec (recommended, Blue/Green)           │
│    Read appspec-rotation-latest.yaml from S3 → CreateDeployment             │
│                                                                              │
│  Rollout mode B — ecs_force_new_deployment (simple, rolling)                │
│    UpdateService(forceNewDeployment=true) on each ECS service               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Rollout Modes

| Mode | Mechanism | Downtime | Requires |
|---|---|---|---|
| `codedeploy_s3_appspec` | CodeDeploy Blue/Green | Zero | AppSpec file pre-uploaded to S3 by CI/CD |
| `ecs_force_new_deployment` | ECS rolling replace | Brief (rolling) | Only ECS cluster/service names |

---

### Example 3: Full Architecture — Automated Password Rotation + Rollout

This example deploys all three modules together. It matches the pattern used in the `tokyo-dev` environment.

#### Prerequisites

Before enabling rotation, ensure:

1. **CloudTrail is enabled** in the account/region. The EventBridge rule in `rds_rotation_rollout` listens for `UpdateSecretVersionStage` via CloudTrail. Without CloudTrail, the rollout Lambda will never be triggered.
2. **Rotation Lambda subnet** must be a **private subnet with a NAT Gateway** (or a Secrets Manager VPC endpoint). The Lambda needs outbound internet access to call the Secrets Manager API. Do **not** use DB subnets or isolated subnets.
3. **AppSpec file in S3** (if using `codedeploy_s3_appspec` mode): CI/CD must upload `appspec-rotation-latest.yaml` to the CodeDeploy S3 bucket before the first rotation runs. Without the file, the Lambda falls back to `appspec.yaml`. If neither key exists, the deployment will fail.

```terraform
# Step 0 — CloudTrail (required for EventBridge → rollout Lambda)
# The rollout Lambda is triggered by an EventBridge rule that filters
# `AWS API Call via CloudTrail` events (UpdateSecretVersionStage).
# Without an active trail recording management write events, EventBridge
# will never fire and the rollout will never run.
#
# Skip this block if your account/organization already has a CloudTrail
# trail capturing management WriteOnly events in this region.
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.environment}-${var.app_name}-cloudtrail-${local.account_id}"

  tags = merge(local.tags, {
    Name = "${var.environment}-${var.app_name}-cloudtrail-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: keep CloudTrail S3 storage cost low; rotation events are
# consumed by EventBridge in real time, so long retention is unnecessary.
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "expire-cloudtrail-logs-30-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${var.environment}-${var.app_name}-eventbridge-cloudtrail"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${var.environment}-${var.app_name}-eventbridge-cloudtrail"
          }
        }
      }
    ]
  })
}

# Minimal trail: WriteOnly + management events is enough for the
# UpdateSecretVersionStage event that triggers the rollout Lambda.
# Setting include_global_service_events = false and is_multi_region_trail = false
# keeps cost minimal in dev environments.
resource "aws_cloudtrail" "eventbridge_source" {
  name                          = "${var.environment}-${var.app_name}-eventbridge-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  is_multi_region_trail         = false
  include_global_service_events = false
  enable_logging                = true

  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]

  tags = merge(local.tags, {
    Name = "${var.environment}-${var.app_name}-eventbridge-cloudtrail"
  })
}

# Step 1 — Core RDS instance
module "rds" {
  source = "../../modules/rds"

  app_name = "${var.environment}-${var.app_name}"
  db_name  = "${var.environment}-${var.app_name}-db"
  vpc_id   = module.vpc.vpc_id

  db_subnet_group_name = module.vpc.database_subnet_group_name
  availability_zone    = "${var.region}${var.azs_name[0]}"

  engine         = "postgres"
  engine_version = "18.1"
  engine_family  = "postgres18"
  instance_class = "db.t4g.small"

  db_database = "clinic"
  db_username = "dbadmin"

  restricted_security_group_ids = [aws_security_group.ecs_tasks.id]

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-${var.app_name}-db-final-snapshot"
  deletion_protection       = true

  monitoring_interval          = 60
  performance_insights_enabled = true

  tags = local.tags
}

# Step 2 — Secrets Manager rotation Lambda (SAR)
# This module deploys the AWS-managed rotation Lambda via CloudFormation SAR.
# The Lambda is placed in private subnets that have NAT Gateway egress so it
# can reach the Secrets Manager service endpoint.
module "rds_secret_rotation" {
  source = "../../modules/rds_secret_rotation"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  secret_arn            = module.rds.password_secret_arn
  db_port               = module.rds.db_port
  vpc_id                = module.vpc.vpc_id

  # Use private subnets (with NAT), NOT database/isolated subnets.
  subnet_ids            = module.vpc.private_subnet_ids
  rds_security_group_id = module.rds.security_group_id

  # Run at 00:00 JST on the 1st of each month (= 15:00 UTC the previous day).
  # When rotation_schedule_expression is set, rotation_interval_days is ignored.
  rotation_schedule_expression = "cron(0 15 1 * ? *)"

  # Set rotate_immediately = true only on first apply to verify the setup.
  # Leave false for subsequent applies to avoid unplanned rotations.
  rotate_immediately = false

  tags = local.tags
}

# Step 3 — Rollout Lambda: syncs rotated password and triggers ECS redeployment
# This module listens for the Secrets Manager AWSCURRENT promotion event via
# EventBridge (CloudTrail integration required) and starts a CodeDeploy deployment
# so the new ECS tasks pick up the new password without downtime.
module "rds_rotation_rollout" {
  source = "../../modules/rds_rotation_rollout"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  rds_password_secret_arn = module.rds.password_secret_arn

  # Blue/Green CodeDeploy rollout (recommended for production).
  rollout_mode  = "codedeploy_s3_appspec"
  delay_seconds = 30

  # Sync the rotated DB password into the consolidated ECS runtime secret so
  # the new ECS task definition revision picks up the updated value.
  sync_runtime_secret_arn = module.ecs_server.app_runtime_secret_arn
  sync_runtime_secret_key = "postgres_password"

  # Targets for operational switch: populate these even when using
  # codedeploy_s3_appspec so that the rollout mode can be changed at runtime
  # (via Lambda env var update) without a Terraform re-apply.
  ecs_targets = [
    {
      cluster_name = module.ecs_cluster_server.cluster_name
      service_name = module.ecs_server.service_name
    }
  ]

  # CI/CD must upload appspec-rotation-latest.yaml to this S3 bucket before
  # the first rotation. The Lambda falls back to appspec.yaml if the primary
  # key is not found.
  codedeploy_targets = [
    {
      application_name      = "${var.environment}-${var.app_name}-server"
      deployment_group_name = "${var.environment}-${var.app_name}-server-dg"
      s3_bucket             = module.codedeploy_server.s3_bucket_name
      s3_key                = "appspec-rotation-latest.yaml"
      bundle_type           = "yaml"
    }
  ]

  tags = local.tags
}
```

#### Rollout Sequence (what happens on rotation day)

1. Secrets Manager triggers the rotation Lambda on schedule.
2. Rotation Lambda (Stage 1):
   - `createSecret` — generates new password in a new secret version.
   - `setSecret` — updates the DB master password via `alter role`.
   - `testSecret` — connects with new credentials to verify.
   - `finishSecret` — promotes the new version to `AWSCURRENT`.
3. Secrets Manager emits `UpdateSecretVersionStage` API call → CloudTrail picks it up → EventBridge fires.
4. Rollout Lambda (Stage 2):
   - Waits `delay_seconds` for Secrets Manager propagation.
   - Reads the new password from the secret.
   - Writes `postgres_password` into the ECS runtime consolidated secret (`sync_runtime_secret_arn`).
   - Reads `appspec-rotation-latest.yaml` from S3 and calls `codedeploy:CreateDeployment`.
5. CodeDeploy starts a Blue/Green deployment. New ECS tasks load the updated secret, which now contains the new password.

---

## Important Notes

- You must provide either `db_subnet_group_name` or `private_subnet_ids`.
- If `skip_final_snapshot = false`, `final_snapshot_identifier` is required.
- If `create_parameter_group = false`, `parameter_group_name` is required.
- Output `password_secret_arn` is `null` when `db_password` is explicitly provided.
- **Rotation Lambda subnet:** Place the rotation Lambda in **private subnets with NAT Gateway** egress, not in DB/isolated subnets. The Lambda needs outbound HTTPS to reach `secretsmanager.<region>.amazonaws.com`. Alternatively, provision a Secrets Manager VPC endpoint in the Lambda's subnet.
- **CloudTrail required for Rollout:** `rds_rotation_rollout` listens for `UpdateSecretVersionStage` via CloudTrail. Ensure an account-level or region-level CloudTrail trail with management event logging (`WriteOnly` is enough) is active, otherwise the EventBridge rule will never fire. See **Step 0** in Example 3 for a minimal in-region trail you can copy directly.
- **AppSpec file for CodeDeploy mode:** Upload `appspec-rotation-latest.yaml` (a static copy of your deployment AppSpec) to the CodeDeploy S3 bucket as part of every CI/CD deploy. The rollout Lambda reads this file at rotation time to create the CodeDeploy deployment.
- **`rotate_immediately`:** Set to `true` only on initial setup to test the rotation pipeline. Leave `false` on all subsequent applies to avoid unplanned rotations during infrastructure changes.
- **`ecs_targets` with `codedeploy_s3_appspec` mode:** Optionally include `ecs_targets` even when using CodeDeploy mode. The values are stored in Lambda env vars and enable switching to `ecs_force_new_deployment` at runtime without a Terraform re-apply.

---

## Inputs — `modules/rds`

| Name                                  | Description                                              | Type           | Default                     | Required |
| ------------------------------------- | -------------------------------------------------------- | -------------- | --------------------------- | :------: |
| app_name                              | Application name used for resource naming                | `string`       | n/a                         |   yes    |
| db_name                               | RDS DB instance identifier                               | `string`       | n/a                         |   yes    |
| vpc_id                                | VPC ID where RDS is deployed                             | `string`       | n/a                         |   yes    |
| availability_zone                     | Primary instance AZ                                      | `string`       | n/a                         |   yes    |
| private_subnet_ids                    | Subnets used when creating a new DB subnet group         | `list(string)` | `[]`                        |   no\*   |
| db_subnet_group_name                  | Existing DB subnet group name from network module        | `string`       | `null`                      |   no\*   |
| db_database                           | Initial database name                                    | `string`       | `"main"`                    |    no    |
| db_username                           | Master username                                          | `string`       | `"dbadmin"`                 |    no    |
| db_password                           | Master password; auto-generated when empty               | `string`       | `""`                        |    no    |
| db_port                               | Database port                                            | `number`       | `5432`                      |    no    |
| engine                                | RDS engine (`postgres`, `mysql`, `mariadb`)              | `string`       | `"postgres"`                |    no    |
| engine_version                        | Engine version                                           | `string`       | `"17.2"`                    |    no    |
| engine_family                         | Parameter group family (e.g. `postgres17`)               | `string`       | `"postgres17"`              |    no    |
| instance_class                        | RDS instance class                                       | `string`       | `"db.t4g.micro"`            |    no    |
| auto_minor_version_upgrade            | Auto-apply minor engine upgrades during maintenance      | `bool`         | `true`                      |    no    |
| allocated_storage                     | Initial storage in GB                                    | `number`       | `20`                        |    no    |
| max_allocated_storage                 | Max autoscaling storage in GB                            | `number`       | `100`                       |    no    |
| storage_type                          | Storage type (`gp2`, `gp3`, `io1`)                       | `string`       | `"gp3"`                     |    no    |
| storage_encrypted                     | Enable storage encryption                                | `bool`         | `true`                      |    no    |
| multi_az                              | Enable Multi-AZ for primary                              | `bool`         | `false`                     |    no    |
| create_replica                        | Create read replica                                      | `bool`         | `false`                     |    no    |
| replica_availability_zone             | Replica AZ                                               | `string`       | `null`                      |    no    |
| replica_instance_class                | Replica instance class (defaults to primary)             | `string`       | `null`                      |    no    |
| backup_retention_period               | Backup retention days                                    | `number`       | `35`                        |    no    |
| backup_window                         | Backup window (UTC)                                      | `string`       | `"20:57-21:27"`             |    no    |
| maintenance_window                    | Maintenance window (UTC)                                 | `string`       | `null`                      |    no    |
| delete_automated_backups              | Delete automated backups on instance deletion            | `bool`         | `false`                     |    no    |
| skip_final_snapshot                   | Skip final snapshot on deletion                          | `bool`         | `false`                     |    no    |
| final_snapshot_identifier             | Final snapshot name (required when `skip_final_snapshot = false`) | `string` | `null`             |    no    |
| restricted_security_group_ids         | Security groups allowed to connect to the DB             | `list(string)` | `[]`                        |    no    |
| deletion_protection                   | Enable deletion protection                               | `bool`         | `true`                      |    no    |
| monitoring_interval                   | Enhanced monitoring interval in seconds (0 to disable)   | `number`       | `60`                        |    no    |
| performance_insights_enabled          | Enable Performance Insights                              | `bool`         | `true`                      |    no    |
| performance_insights_retention_period | Performance Insights retention days                      | `number`       | `7`                         |    no    |
| enabled_cloudwatch_logs_exports       | Log types exported to CloudWatch                         | `list(string)` | `["postgresql", "upgrade"]` |    no    |
| cloudwatch_log_retention_in_days      | CW log retention days                                    | `number`       | `30`                        |    no    |
| create_parameter_group                | Create a custom parameter group                          | `bool`         | `true`                      |    no    |
| parameter_group_name                  | Existing parameter group name (when `create_parameter_group = false`) | `string` | `null`        |    no    |
| custom_parameters                     | Additional DB parameters to merge into parameter group   | `list(object)` | `[]`                        |    no    |
| enable_slow_query_log                 | Enable slow query logging (`log_min_duration_statement`) | `bool`         | `true`                      |    no    |
| slow_query_log_min_duration_ms        | Slow query threshold in milliseconds                     | `number`       | `500`                       |    no    |
| enable_log_lock_waits                 | Enable lock wait logging                                 | `bool`         | `true`                      |    no    |
| enable_track_io_timing                | Enable `track_io_timing` for query analysis              | `bool`         | `true`                      |    no    |
| idle_in_transaction_session_timeout_ms | Kill idle-in-transaction sessions after this many ms    | `number`       | `30000`                     |    no    |
| enable_s3_integration                 | Enable RDS S3 import/export integration (PostgreSQL)     | `bool`         | `false`                     |    no    |
| s3_bucket_arns                        | S3 bucket ARNs for import/export policy                  | `list(string)` | `null`                      |    no    |
| tags                                  | Tags applied to all resources                            | `map(string)`  | `{}`                        |    no    |

\*Either `db_subnet_group_name` or `private_subnet_ids` must be provided.

## Outputs — `modules/rds`

| Name                        | Description                                              |
| --------------------------- | -------------------------------------------------------- |
| db_instance_id              | RDS instance ID                                          |
| db_instance_identifier      | RDS instance identifier                                  |
| db_instance_arn             | RDS instance ARN                                         |
| db_endpoint                 | DB endpoint in `host:port` format                        |
| db_hostname                 | DB hostname only (without port)                          |
| db_port                     | DB port                                                  |
| db_name                     | Initial database name                                    |
| db_schema                   | DB schema (`public`)                                     |
| db_username                 | Master username                                          |
| db_engine                   | Engine name                                              |
| db_engine_version           | Engine version                                           |
| replica_instance_id         | Read replica ID (or `null`)                              |
| replica_instance_identifier | Read replica identifier (or `null`)                      |
| replica_endpoint            | Read replica endpoint (or `null`)                        |
| replica_hostname            | Read replica hostname (or `null`)                        |
| security_group_id           | RDS security group ID                                    |
| db_subnet_group_name        | Effective DB subnet group name                           |
| db_subnet_group_id          | Created DB subnet group ID (or `null` if external)       |
| db_subnet_group_arn         | Created DB subnet group ARN (or `null` if external)      |
| password_secret_arn         | Secrets Manager secret ARN for RDS credentials (or `null`) |
| password_secret_name        | Secrets Manager secret name (or `null`)                  |
| monitoring_role_arn         | Enhanced monitoring role ARN (or `null`)                 |
| s3_export_role_arn          | RDS S3 export role ARN (or `null`)                       |
| s3_import_role_arn          | RDS S3 import role ARN (or `null`)                       |
| connection_string_template  | Connection string template (password omitted)            |

---

## Inputs — `modules/rds_secret_rotation`

| Name                        | Description                                                         | Type           | Default | Required |
| --------------------------- | ------------------------------------------------------------------- | -------------- | ------- | :------: |
| app_name                    | Application name prefix for resource naming                         | `string`       | n/a     |   yes    |
| region                      | AWS region                                                          | `string`       | n/a     |   yes    |
| secret_arn                  | Secrets Manager secret ARN from `module.rds.password_secret_arn`   | `string`       | n/a     |   yes    |
| db_port                     | RDS port                                                            | `number`       | `5432`  |    no    |
| vpc_id                      | VPC ID for the rotation Lambda networking                           | `string`       | n/a     |   yes    |
| subnet_ids                  | **Private subnets with NAT** for the rotation Lambda                | `list(string)` | n/a     |   yes    |
| rds_security_group_id       | Security group ID of the RDS instance (ingress rule will be added) | `string`       | n/a     |   yes    |
| rotation_interval_days      | Days between rotations (ignored when `rotation_schedule_expression` is set) | `number` | `30` |    no |
| rotation_schedule_expression | Secrets Manager cron/rate schedule expression                      | `string`       | `null`  |    no    |
| rotate_immediately          | Rotate immediately on first apply (use only for initial testing)    | `bool`         | `false` |    no    |
| tags                        | Tags applied to all resources                                       | `map(string)`  | `{}`    |    no    |

## Outputs — `modules/rds_secret_rotation`

| Name                        | Description                            |
| --------------------------- | -------------------------------------- |
| rotation_lambda_name        | Rotation Lambda function name          |
| rotation_lambda_arn         | Rotation Lambda function ARN           |
| rotation_enabled_secret_arn | Secret ARN with rotation enabled       |

---

## Inputs — `modules/rds_rotation_rollout`

| Name                    | Description                                                                               | Type           | Default                   | Required |
| ----------------------- | ----------------------------------------------------------------------------------------- | -------------- | ------------------------- | :------: |
| app_name                | Application name prefix                                                                   | `string`       | n/a                       |   yes    |
| region                  | AWS region                                                                                | `string`       | n/a                       |   yes    |
| rds_password_secret_arn | RDS secret ARN — EventBridge rule filters on this ARN                                    | `string`       | n/a                       |   yes    |
| rollout_mode            | `codedeploy_s3_appspec` or `ecs_force_new_deployment`                                    | `string`       | `"codedeploy_s3_appspec"` |    no    |
| delay_seconds           | Seconds to wait after rotation event before triggering rollout (30–60)                   | `number`       | `30`                      |    no    |
| sync_runtime_secret_arn | Consolidated ECS runtime secret ARN to update with the new password                      | `string`       | `null`                    |    no    |
| sync_runtime_secret_key | JSON key to update inside the consolidated secret                                         | `string`       | `"postgres_password"`     |    no    |
| ecs_targets             | ECS services to redeploy (required when `rollout_mode = ecs_force_new_deployment`)       | `list(object)` | `[]`                      |    no    |
| codedeploy_targets      | CodeDeploy application/DG/S3 config (required when `rollout_mode = codedeploy_s3_appspec`) | `list(object)` | `[]`                  |    no    |
| lambda_timeout_seconds  | Lambda timeout in seconds                                                                 | `number`       | `180`                     |    no    |
| lambda_memory_size      | Lambda memory size in MB                                                                  | `number`       | `256`                     |    no    |
| log_retention_in_days   | CloudWatch log retention days for rollout Lambda                                          | `number`       | `30`                      |    no    |
| tags                    | Tags applied to all resources                                                             | `map(string)`  | `{}`                      |    no    |

### `codedeploy_targets` object fields

| Field                  | Type     | Default        | Description                                              |
| ---------------------- | -------- | -------------- | -------------------------------------------------------- |
| application_name       | `string` | required       | CodeDeploy application name                              |
| deployment_group_name  | `string` | required       | CodeDeploy deployment group name                         |
| s3_bucket              | `string` | required       | S3 bucket containing the AppSpec revision                |
| s3_key                 | `string` | required       | Primary S3 key (e.g. `appspec-rotation-latest.yaml`)     |
| fallback_s3_key        | `string` | `"appspec.yaml"` | Fallback key if primary is not found in S3             |
| bundle_type            | `string` | `"yaml"`       | `yaml`, `json`, `zip`, `tar`, `tgz`                     |

## Outputs — `modules/rds_rotation_rollout`

| Name                 | Description                                          |
| -------------------- | ---------------------------------------------------- |
| lambda_function_name | Rollout Lambda function name                         |
| lambda_function_arn  | Rollout Lambda function ARN                          |
| eventbridge_rule_arn | EventBridge rule ARN listening for rotation events   |

---

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | >= 5.0  |
| random    | >= 3.0  |

## License

Apache 2 Licensed. See LICENSE for full details.
