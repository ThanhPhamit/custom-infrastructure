# EventBridge Rule
resource "aws_cloudwatch_event_rule" "this" {
  name                = local.rule_name
  description         = var.rule_description
  schedule_expression = var.schedule_expression
  state               = var.enable_rule ? "ENABLED" : "DISABLED"

  tags = merge(var.tags, {
    Name = local.rule_name
  })
}

# IAM Role for EventBridge to invoke targets
module "eventbridge_role" {
  source = "../iam_role"

  name        = "${var.app_name}-eventbridge-role"
  description = "EventBridge role for ${var.app_name} to invoke targets"
  identifier  = "events.amazonaws.com"

  policy_arns_map = {}

  inline_policies = merge(
    local.is_ecs_target ? {
      "ecs-run-task" = {
        policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "ecs:RunTask"
              ]
              Resource = var.ecs_task_definition_arn
            },
            {
              Effect = "Allow"
              Action = [
                "iam:PassRole"
              ]
              Resource = "*"
              Condition = {
                StringLike = {
                  "iam:PassedToService" = "ecs-tasks.amazonaws.com"
                }
              }
            }
          ]
        })
      }
    } : {},
    local.is_lambda_target ? {
      "lambda-invoke" = {
        policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "lambda:InvokeFunction"
              ]
              Resource = var.lambda_function_arn
            }
          ]
        })
      }
    } : {}
  )

  tags = var.tags
}

# Lambda permission to allow EventBridge to invoke
resource "aws_lambda_permission" "eventbridge" {
  count = local.is_lambda_target ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

# EventBridge Target for ECS
resource "aws_cloudwatch_event_target" "ecs" {
  count = local.is_ecs_target ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.app_name}-ecs-target"
  arn       = var.ecs_cluster_arn
  role_arn  = module.eventbridge_role.iam_role_arn

  ecs_target {
    task_count          = var.ecs_task_count
    task_definition_arn = var.ecs_task_definition_arn
    launch_type         = var.ecs_launch_type
    platform_version    = var.ecs_platform_version

    network_configuration {
      subnets          = var.ecs_subnet_ids
      security_groups  = var.ecs_security_group_ids
      assign_public_ip = var.ecs_assign_public_ip
    }
  }

  dynamic "input_transformer" {
    for_each = var.target_input_transformer != null ? [var.target_input_transformer] : []

    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  input = var.target_input
}

# EventBridge Target for Lambda
resource "aws_cloudwatch_event_target" "lambda" {
  count = local.is_lambda_target ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.app_name}-lambda-target"
  arn       = var.lambda_function_arn

  dynamic "input_transformer" {
    for_each = var.target_input_transformer != null ? [var.target_input_transformer] : []

    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  input = var.lambda_input != null ? var.lambda_input : var.target_input
}
