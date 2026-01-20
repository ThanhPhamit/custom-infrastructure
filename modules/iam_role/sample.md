# Network Module - Sample Usage

## main.tf

```terraform
module "ecs_task_execution_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-ecs-task-execution-role"
  identifier = "ecs-tasks.amazonaws.com"

  policy_arns_map = {
    "policy_1" = aws_iam_policy.ecs_task_execution_policy.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-task-execution-role"
    }
  )
}
```

## variables.tf

```terraform

```

## terraform.tfvars

```hcl

```

## Outputs

```terraform

```
