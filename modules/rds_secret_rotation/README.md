# RDS Secret Rotation Module

Terraform module to enable native AWS Secrets Manager rotation for RDS credentials by deploying the AWS managed PostgreSQL single-user rotation Lambda from Serverless Application Repository.

## Features

- Deploys AWS managed rotation Lambda application (SAR)
- Creates dedicated security group for rotation Lambda
- Opens controlled ingress from rotation Lambda SG to RDS SG on DB port
- Enables `aws_secretsmanager_secret_rotation` schedule on target secret
- Configures Secrets Manager endpoint for the selected AWS region
- Uses partition-aware ARN and endpoint construction

## Usage

### Example 1: Basic Rotation Enablement

```terraform
module "rds_secret_rotation" {
  source = "../../modules/rds_secret_rotation"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  secret_arn            = module.rds.password_secret_arn
  db_port               = module.rds.db_port
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  rds_security_group_id = module.rds.security_group_id

  rotation_interval_days = 30

  tags = local.tags
}
```

### Example 2: Custom Rotation Interval

```terraform
module "rds_secret_rotation" {
  source = "../../modules/rds_secret_rotation"

  app_name = "prod-care-hub"
  region   = "ap-northeast-1"

  secret_arn            = module.rds.password_secret_arn
  db_port               = 5432
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  rds_security_group_id = module.rds.security_group_id

  rotation_interval_days = 14

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## Rotation Behavior

- Rotation is executed by AWS managed Lambda function.
- Secret value is updated with new credentials by Secrets Manager.
- Module `rds_rotation_rollout` can be chained to trigger ECS/CodeDeploy rollout after successful rotation.

## Inputs

| Name                   | Description                                            | Type           | Default | Required |
| ---------------------- | ------------------------------------------------------ | -------------- | ------- | :------: |
| app_name               | Prefix for resource naming                             | `string`       | n/a     |   yes    |
| region                 | AWS region                                             | `string`       | n/a     |   yes    |
| secret_arn             | Secrets Manager secret ARN for RDS credentials         | `string`       | n/a     |   yes    |
| db_port                | Database port                                          | `number`       | `5432`  |    no    |
| vpc_id                 | VPC ID for rotation Lambda networking                  | `string`       | n/a     |   yes    |
| subnet_ids             | Subnet IDs for rotation Lambda                         | `list(string)` | n/a     |   yes    |
| rds_security_group_id  | RDS security group ID to allow rotation Lambda ingress | `string`       | n/a     |   yes    |
| rotation_interval_days | Rotation interval in days                              | `number`       | `30`    |    no    |
| tags                   | Tags for all resources                                 | `map(string)`  | `{}`    |    no    |

## Outputs

| Name                        | Description                               |
| --------------------------- | ----------------------------------------- |
| rotation_lambda_name        | Rotation Lambda function name             |
| rotation_lambda_arn         | Rotation Lambda function ARN              |
| rotation_enabled_secret_arn | Secret ARN with enabled rotation schedule |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.0   |
| aws       | >= 6.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
