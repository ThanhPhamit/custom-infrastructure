# AWS IAM Role Terraform Module

Terraform module which creates an IAM role with attached policies.

## Features

This module supports creating:

- **IAM Role** - Role with trust policy
- **Policy Attachments** - Multiple policy attachments
- **Service Principal** - Support for various AWS service principals

## Usage

### Example 1: ECS Task Execution Role

```terraform
module "ecs_task_execution_role" {
  source = "../../modules/iam_role"

  name       = "${var.app_name}-ecs-task-execution-role"
  identifier = "ecs-tasks.amazonaws.com"

  policy_arns_map = {
    "ecs_task_execution" = aws_iam_policy.ecs_task_execution_policy.arn
    "ecr_read"           = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "logs"               = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: ECS Task Role

```terraform
module "ecs_task_role" {
  source = "../../modules/iam_role"

  name       = "${var.app_name}-ecs-task-role"
  identifier = "ecs-tasks.amazonaws.com"

  policy_arns_map = {
    "s3_access"     = aws_iam_policy.s3_access_policy.arn
    "secrets"       = aws_iam_policy.secrets_access_policy.arn
    "ssm_messages"  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}
```

### Example 3: Lambda Execution Role

```terraform
module "lambda_role" {
  source = "../../modules/iam_role"

  name       = "${var.app_name}-lambda-role"
  identifier = "lambda.amazonaws.com"

  policy_arns_map = {
    "basic_execution" = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    "vpc_access"      = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    "custom"          = aws_iam_policy.lambda_custom_policy.arn
  }

  tags = local.tags
}
```

### Example 4: CodeDeploy Role

```terraform
module "codedeploy_role" {
  source = "../../modules/iam_role"

  name       = "${var.app_name}-codedeploy-role"
  identifier = "codedeploy.amazonaws.com"

  policy_arns_map = {
    "codedeploy_ecs" = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  }

  tags = local.tags
}
```

## Common Service Principals

| Service           | Identifier                   |
| ----------------- | ---------------------------- |
| ECS Tasks         | `ecs-tasks.amazonaws.com`    |
| Lambda            | `lambda.amazonaws.com`       |
| EC2               | `ec2.amazonaws.com`          |
| CodeDeploy        | `codedeploy.amazonaws.com`   |
| CodeBuild         | `codebuild.amazonaws.com`    |
| CodePipeline      | `codepipeline.amazonaws.com` |
| CloudWatch Events | `events.amazonaws.com`       |
| API Gateway       | `apigateway.amazonaws.com`   |
| S3                | `s3.amazonaws.com`           |

## AWS Managed Policies (Common)

| Policy                               | Use Case               |
| ------------------------------------ | ---------------------- |
| `AmazonEC2ContainerRegistryReadOnly` | ECR image pull         |
| `AmazonECSTaskExecutionRolePolicy`   | ECS task execution     |
| `CloudWatchLogsFullAccess`           | CloudWatch logging     |
| `AWSLambdaBasicExecutionRole`        | Lambda basic execution |
| `AWSLambdaVPCAccessExecutionRole`    | Lambda VPC access      |
| `AmazonSSMManagedInstanceCore`       | SSM/ECS Exec access    |
| `AWSCodeDeployRoleForECS`            | CodeDeploy for ECS     |

## Inputs

| Name            | Description                  | Type          | Default | Required |
| --------------- | ---------------------------- | ------------- | ------- | :------: |
| name            | Name of the IAM role         | `string`      | n/a     |   yes    |
| identifier      | AWS service principal        | `string`      | n/a     |   yes    |
| policy_arns_map | Map of policy ARNs to attach | `map(string)` | n/a     |   yes    |
| tags            | Tags to apply to resources   | `map(string)` | `{}`    |    no    |

## Outputs

| Name          | Description          |
| ------------- | -------------------- |
| iam_role_arn  | ARN of the IAM role  |
| iam_role_name | Name of the IAM role |

## Best Practices

1. **Least Privilege**: Only attach necessary policies
2. **Custom Policies**: Prefer custom policies over AWS managed when possible
3. **Naming Convention**: Use descriptive names (e.g., `app-service-role`)
4. **Tagging**: Always include environment and purpose tags

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
