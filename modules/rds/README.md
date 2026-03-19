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

  skip_final_snapshot  = true
  deletion_protection  = false
  monitoring_interval  = 0
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

### Example 3: Full Architecture with Automated Password Rotation & Secret Rollout

This example demonstrates how to deploy the RDS instance alongside automated password rotation (via Lambda) and automatic secret rollout to ECS and CodeDeploy.

```terraform
# 1. Provide the main RDS database
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

  tags = local.tags
}

# 2. Configure Secret Rotation (Lambda Rotator)
module "rds_secret_rotation" {
  source = "../../modules/rds_secret_rotation"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  # Attach to the generated RDS secret
  secret_arn            = module.rds.password_secret_arn
  db_port               = module.rds.db_port
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  rds_security_group_id = module.rds.security_group_id

  # Schedule: 00:00 JST on the 1st of each month (= 15:00 UTC previous day)
  rotation_schedule_expression = "cron(0 15 1 * ? *)"

  tags = local.tags
}

# 3. Rollout rotated passwords to ECS and trigger CodeDeploy
module "rds_rotation_rollout" {
  source = "../../modules/rds_rotation_rollout"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  # Trigger source: native Secrets Manager event (Rotation Succeeded)
  rds_password_secret_arn = module.rds.password_secret_arn

  # Preferred rollout mode for this stack (CodeDeploy Blue/Green)
  rollout_mode  = "codedeploy_s3_appspec"
  delay_seconds = 30

  # Keep consolidated runtime secret in sync with rotated DB password
  sync_runtime_secret_arn = module.ecs_server.app_runtime_secret_arn
  sync_runtime_secret_key = "postgres_password"

  # Fallback target (ECS standard deployment)
  ecs_targets = [
    {
      cluster_name = module.ecs_cluster_server.cluster_name
      service_name = module.ecs_server.service_name
    }
  ]

  # Primary target (CodeDeploy deployment configuration)
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

## Important Notes

- You must provide either `db_subnet_group_name` or `private_subnet_ids`.
- If `skip_final_snapshot = false`, `final_snapshot_identifier` is required.
- If `create_parameter_group = false`, `parameter_group_name` is required.
- Output `password_secret_arn` is `null` when `db_password` is explicitly provided.
- **VPC Endpoint Requirement**: If the RDS instance is placed in a private subnet lacking a NAT Gateway, you **must** provision a VPC Endpoint for Secrets Manager. Without this endpoint, the Lambda function inside the VPC will be unable to communicate with the Secrets Manager service to rotate the credentials.

## Inputs

| Name                                  | Description                                | Type           | Default                     | Required |
| ------------------------------------- | ------------------------------------------ | -------------- | --------------------------- | :------: |
| app_name                              | Application name used for resource naming  | `string`       | n/a                         |   yes    |
| db_name                               | RDS DB instance identifier                 | `string`       | n/a                         |   yes    |
| vpc_id                                | VPC ID where RDS is deployed               | `string`       | n/a                         |   yes    |
| availability_zone                     | Primary instance AZ                        | `string`       | n/a                         |   yes    |
| private_subnet_ids                    | Subnets used when creating DB subnet group | `list(string)` | `[]`                        |   no\*   |
| db_subnet_group_name                  | Existing DB subnet group name              | `string`       | `null`                      |   no\*   |
| db_database                           | Initial database name                      | `string`       | `"main"`                    |    no    |
| db_username                           | Master username                            | `string`       | `"dbadmin"`                 |    no    |
| db_password                           | Master password, auto-generated when empty | `string`       | `""`                        |    no    |
| db_port                               | Database port                              | `number`       | `5432`                      |    no    |
| engine                                | RDS engine                                 | `string`       | `"postgres"`                |    no    |
| engine_version                        | Engine version                             | `string`       | `"17.2"`                    |    no    |
| engine_family                         | Parameter group family                     | `string`       | `"postgres17"`              |    no    |
| instance_class                        | RDS instance class                         | `string`       | `"db.t4g.micro"`            |    no    |
| allocated_storage                     | Initial storage in GB                      | `number`       | `20`                        |    no    |
| max_allocated_storage                 | Max autoscaling storage in GB              | `number`       | `100`                       |    no    |
| storage_type                          | Storage type (`gp2`, `gp3`, `io1`)         | `string`       | `"gp3"`                     |    no    |
| storage_encrypted                     | Enable storage encryption                  | `bool`         | `true`                      |    no    |
| multi_az                              | Enable Multi-AZ for primary                | `bool`         | `false`                     |    no    |
| create_replica                        | Create read replica                        | `bool`         | `false`                     |    no    |
| replica_availability_zone             | Replica AZ                                 | `string`       | `null`                      |    no    |
| replica_instance_class                | Replica instance class                     | `string`       | `null`                      |    no    |
| backup_retention_period               | Backup retention days                      | `number`       | `35`                        |    no    |
| backup_window                         | Backup window (UTC)                        | `string`       | `"20:57-21:27"`             |    no    |
| delete_automated_backups              | Delete automated backups on delete         | `bool`         | `false`                     |    no    |
| skip_final_snapshot                   | Skip final snapshot on delete              | `bool`         | `false`                     |    no    |
| final_snapshot_identifier             | Final snapshot identifier                  | `string`       | `null`                      |    no    |
| restricted_security_group_ids         | Security groups allowed to connect to DB   | `list(string)` | `[]`                        |    no    |
| deletion_protection                   | Enable deletion protection                 | `bool`         | `true`                      |    no    |
| monitoring_interval                   | Enhanced monitoring interval               | `number`       | `60`                        |    no    |
| performance_insights_enabled          | Enable Performance Insights                | `bool`         | `true`                      |    no    |
| performance_insights_retention_period | PI retention days                          | `number`       | `7`                         |    no    |
| enabled_cloudwatch_logs_exports       | Logs exported to CloudWatch                | `list(string)` | `["postgresql", "upgrade"]` |    no    |
| create_parameter_group                | Create parameter group                     | `bool`         | `true`                      |    no    |
| parameter_group_name                  | Existing parameter group name              | `string`       | `null`                      |    no    |
| custom_parameters                     | Additional DB parameters                   | `list(object)` | `[]`                        |    no    |
| enable_s3_integration                 | Enable RDS S3 integration                  | `bool`         | `false`                     |    no    |
| s3_bucket_arns                        | S3 bucket ARNs for import/export policy    | `list(string)` | `null`                      |    no    |
| tags                                  | Tags for all resources                     | `map(string)`  | `{}`                        |    no    |

\*Either `db_subnet_group_name` or `private_subnet_ids` must be provided.

## Outputs

| Name                        | Description                                 |
| --------------------------- | ------------------------------------------- |
| db_instance_id              | RDS instance ID                             |
| db_instance_identifier      | RDS instance identifier                     |
| db_instance_arn             | RDS instance ARN                            |
| db_endpoint                 | DB endpoint in `host:port` format           |
| db_hostname                 | DB hostname only                            |
| db_port                     | DB port                                     |
| db_name                     | Initial DB name                             |
| db_schema                   | DB schema (`public`)                        |
| db_username                 | Master username                             |
| db_engine                   | Engine name                                 |
| db_engine_version           | Engine version                              |
| replica_instance_id         | Read replica ID (or `null`)                 |
| replica_instance_identifier | Read replica identifier (or `null`)         |
| replica_endpoint            | Read replica endpoint (or `null`)           |
| replica_hostname            | Read replica hostname (or `null`)           |
| security_group_id           | RDS security group ID                       |
| db_subnet_group_name        | Effective DB subnet group name              |
| db_subnet_group_id          | Created DB subnet group ID (or `null`)      |
| db_subnet_group_arn         | Created DB subnet group ARN (or `null`)     |
| password_secret_arn         | RDS credentials secret ARN (or `null`)      |
| password_secret_name        | RDS credentials secret name (or `null`)     |
| monitoring_role_arn         | Enhanced monitoring role ARN (or `null`)    |
| s3_export_role_arn          | RDS S3 export role ARN (or `null`)          |
| s3_import_role_arn          | RDS S3 import role ARN (or `null`)          |
| connection_string_template  | Connection string template without password |

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | >= 5.0  |
| random    | >= 3.0  |

## License

Apache 2 Licensed. See LICENSE for full details.
