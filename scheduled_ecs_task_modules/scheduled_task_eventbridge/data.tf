data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  rule_name = var.rule_name != null ? var.rule_name : "${var.app_name}-scheduled-rule"

  # Determine if we need to create ECS-specific IAM permissions
  is_ecs_target = var.target_type == "ecs"

  # Determine if we need to create Lambda-specific IAM permissions
  is_lambda_target = var.target_type == "lambda"
}
