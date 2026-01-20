# ECS Scheduled Task Module

A Terraform module for creating an ECS cluster, task definition, IAM roles, and CloudWatch logs for scheduled tasks running on Fargate.

## Features

- ✅ ECS Cluster (using `ecs_cluster` module)
- ✅ Fargate-compatible task definition
- ✅ CloudWatch log group with configurable retention
- ✅ IAM roles for task execution and application permissions
- ✅ Support for environment variables and secrets
- ✅ Flexible CPU and memory configurations

## Usage

```hcl
module "ecs_scheduled_task" {
  source = "../modules/ecs_scheduled_task"

  app_name    = "welfan-remark-ai-tool"
  cluster_name = "welfan-remark-ai-tool"

  # Container Configuration
  ecr_image_uri   = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-app:latest"
  container_name  = "app"
  task_cpu        = "256"
  task_memory     = "512"

  # Environment Variables
  container_environment = [
    {
      name  = "ENVIRONMENT"
      value = "staging"
    },
    {
      name  = "LOG_LEVEL"
      value = "info"
    }
  ]

  # Secrets from AWS Secrets Manager
  container_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = "arn:aws:secretsmanager:region:account:secret:db-url"
    }
  ]

  # CloudWatch Logs
  log_retention_days = 30

  # IAM Permissions
  task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  tags = local.tags
}
```

## CPU and Memory Combinations

Valid Fargate CPU and memory combinations:

| CPU (vCPU) | Memory (GB)            |
| ---------- | ---------------------- |
| 256 (.25)  | 0.5, 1, 2              |
| 512 (.5)   | 1, 2, 3, 4             |
| 1024 (1)   | 2-8 (1 GB increments)  |
| 2048 (2)   | 4-16 (1 GB increments) |
| 4096 (4)   | 8-30 (1 GB increments) |

## Inputs

| Name               | Description                          | Type          | Default    | Required |
| ------------------ | ------------------------------------ | ------------- | ---------- | :------: |
| app_name           | Application name for resource naming | `string`      | n/a        |   yes    |
| ecr_image_uri      | ECR image URI for the container      | `string`      | n/a        |   yes    |
| cluster_name       | Name of the ECS cluster              | `string`      | `app_name` |    no    |
| container_name     | Name of the container                | `string`      | `"app"`    |    no    |
| task_cpu           | CPU units for the task               | `string`      | `"256"`    |    no    |
| task_memory        | Memory for the task in MB            | `string`      | `"512"`    |    no    |
| log_retention_days | CloudWatch log retention             | `number`      | `30`       |    no    |
| tags               | Tags to apply to all resources       | `map(string)` | `{}`       |    no    |

## Outputs

| Name                    | Description                      |
| ----------------------- | -------------------------------- |
| cluster_arn             | ARN of the ECS cluster           |
| cluster_name            | Name of the ECS cluster          |
| task_definition_arn     | ARN of the ECS task definition   |
| task_execution_role_arn | ARN of the task execution role   |
| task_role_arn           | ARN of the task role             |
| log_group_name          | Name of the CloudWatch log group |

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0
