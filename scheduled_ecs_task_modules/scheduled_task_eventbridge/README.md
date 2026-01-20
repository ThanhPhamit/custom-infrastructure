# Scheduled Task EventBridge Module

A flexible Terraform module for creating EventBridge (CloudWatch Events) scheduled rules that can trigger ECS tasks or Lambda functions.

## Features

- ✅ Support for ECS task targets
- ✅ Support for Lambda function targets
- ✅ Flexible schedule expressions (rate or cron)
- ✅ Automatic IAM role and policy management
- ✅ Input transformation support
- ✅ Enable/disable rule without destroying resources

## Usage

### Trigger ECS Task

```hcl
module "ecs_scheduler" {
  source = "../modules/scheduled_task_eventbridge"

  app_name            = "my-app"
  schedule_expression = "rate(1 hour)"

  # Target Configuration
  target_type             = "ecs"
  ecs_cluster_arn         = module.ecs_cluster.cluster_arn
  ecs_task_definition_arn = module.ecs_task.task_definition_arn
  ecs_task_count          = 1
  ecs_subnet_ids          = data.aws_subnets.private.ids
  ecs_security_group_ids  = [aws_security_group.ecs.id]
  ecs_assign_public_ip    = false
  ecs_launch_type         = "FARGATE"

  tags = local.tags
}
```

### Trigger Lambda Function

```hcl
module "lambda_scheduler" {
  source = "../modules/scheduled_task_eventbridge"

  app_name            = "my-app"
  schedule_expression = "cron(0 12 * * ? *)"  # Daily at 12:00 UTC

  # Target Configuration
  target_type         = "lambda"
  lambda_function_arn = aws_lambda_function.my_function.arn
  lambda_input        = jsonencode({
    action = "process"
    source = "scheduler"
  })

  tags = local.tags
}
```

## Schedule Expressions

- **Rate-based**: `rate(1 hour)`, `rate(30 minutes)`, `rate(1 day)`
- **Cron-based**: `cron(0 12 * * ? *)` - Daily at 12:00 UTC
  - Format: `cron(Minutes Hours Day-of-month Month Day-of-week Year)`

## Inputs

| Name                    | Description                          | Type          | Default | Required |
| ----------------------- | ------------------------------------ | ------------- | ------- | :------: |
| app_name                | Application name for resource naming | `string`      | n/a     |   yes    |
| schedule_expression     | EventBridge schedule expression      | `string`      | n/a     |   yes    |
| target_type             | Type of target (ecs or lambda)       | `string`      | n/a     |   yes    |
| ecs_cluster_arn         | ARN of the ECS cluster               | `string`      | `null`  |    no    |
| ecs_task_definition_arn | ARN of the ECS task definition       | `string`      | `null`  |    no    |
| lambda_function_arn     | ARN of the Lambda function           | `string`      | `null`  |    no    |
| enable_rule             | Enable the EventBridge rule          | `bool`        | `true`  |    no    |
| tags                    | Tags to apply to all resources       | `map(string)` | `{}`    |    no    |

## Outputs

| Name                 | Description                     |
| -------------------- | ------------------------------- |
| rule_id              | ID of the EventBridge rule      |
| rule_arn             | ARN of the EventBridge rule     |
| rule_name            | Name of the EventBridge rule    |
| eventbridge_role_arn | ARN of the EventBridge IAM role |

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0
