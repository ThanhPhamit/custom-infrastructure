# RDS Password Rotation Rollout Module

Terraform module that listens for Secrets Manager `Rotation Succeeded` events and triggers post-rotation workload rollout.

## Features

- EventBridge rule for native Secrets Manager rotation events
- Lambda orchestrator for controlled rollout execution
- Optional runtime secret sync (`postgres_password` into consolidated app secret)
- Two rollout modes:
  - `codedeploy_s3_appspec`
  - `ecs_force_new_deployment`
- Mode-aware IAM policy with least-privilege permissions
- Configurable delay to absorb secret propagation time

## Event Flow

1. Secrets Manager rotates RDS credentials.
2. EventBridge receives `source=aws.secretsmanager`, `detail-type=Rotation Succeeded`.
3. Lambda validates event and target secret ARN.
4. Lambda waits `delay_seconds`.
5. Lambda optionally syncs runtime secret.
6. Lambda triggers CodeDeploy or ECS rollout.

## Usage

### Example 1: CodeDeploy Blue/Green (Recommended)

```terraform
module "rds_rotation_rollout" {
  source = "../../modules/rds_rotation_rollout"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  rds_password_secret_arn = module.rds.password_secret_arn
  rollout_mode            = "codedeploy_s3_appspec"
  delay_seconds           = 30

  sync_runtime_secret_arn = module.ecs_server.app_runtime_secret_arn
  sync_runtime_secret_key = "postgres_password"

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

### Example 2: ECS Force New Deployment

```terraform
module "rds_rotation_rollout" {
  source = "../../modules/rds_rotation_rollout"

  app_name = "${var.environment}-${var.app_name}"
  region   = var.region

  rds_password_secret_arn = module.rds.password_secret_arn
  rollout_mode            = "ecs_force_new_deployment"
  delay_seconds           = 30

  sync_runtime_secret_arn = module.ecs_server.app_runtime_secret_arn

  ecs_targets = [
    {
      cluster_name = module.ecs_cluster_server.cluster_name
      service_name = module.ecs_server.service_name
    }
  ]

  tags = local.tags
}
```

## Important Notes

- This module handles rollout orchestration only; it does not create the rotation schedule itself.
- For `codedeploy_s3_appspec`, CI/CD should continuously publish a stable key (for example `appspec-rotation-latest.yaml`).
- `ecs_targets` must be set when using `ecs_force_new_deployment`.
- `codedeploy_targets` must be set when using `codedeploy_s3_appspec`.

## Inputs

| Name                    | Description                                                              | Type           | Default                   | Required |
| ----------------------- | ------------------------------------------------------------------------ | -------------- | ------------------------- | :------: |
| app_name                | Prefix for resource naming                                               | `string`       | n/a                       |   yes    |
| region                  | AWS region                                                               | `string`       | n/a                       |   yes    |
| rds_password_secret_arn | Rotated RDS credentials secret ARN                                       | `string`       | n/a                       |   yes    |
| rollout_mode            | Rollout strategy (`codedeploy_s3_appspec` or `ecs_force_new_deployment`) | `string`       | `"codedeploy_s3_appspec"` |    no    |
| ecs_targets             | ECS target services for force deployment mode                            | `list(object)` | `[]`                      |    no    |
| codedeploy_targets      | CodeDeploy application/group/revision targets                            | `list(object)` | `[]`                      |    no    |
| delay_seconds           | Delay before rollout                                                     | `number`       | `30`                      |    no    |
| sync_runtime_secret_arn | Consolidated app runtime secret ARN to update                            | `string`       | `null`                    |    no    |
| sync_runtime_secret_key | JSON key updated in runtime secret                                       | `string`       | `"postgres_password"`     |    no    |
| lambda_timeout_seconds  | Lambda timeout in seconds                                                | `number`       | `180`                     |    no    |
| lambda_memory_size      | Lambda memory size (MB)                                                  | `number`       | `256`                     |    no    |
| log_retention_in_days   | CloudWatch log retention                                                 | `number`       | `30`                      |    no    |
| tags                    | Tags for all resources                                                   | `map(string)`  | `{}`                      |    no    |

## Outputs

| Name                 | Description                                 |
| -------------------- | ------------------------------------------- |
| lambda_function_name | Rollout Lambda function name                |
| lambda_function_arn  | Rollout Lambda function ARN                 |
| eventbridge_rule_arn | EventBridge rule ARN for rotation succeeded |

## Requirements

| Name                             | Version  |
| -------------------------------- | -------- |
| terraform                        | >= 1.0   |
| aws                              | >= 6.0.0 |
| terraform-aws-modules/lambda/aws | = 8.1.2  |

## License

Apache 2 Licensed. See LICENSE for full details.
