locals {
  # Derive instance IDs from the ARNs (…:instance/i-0abc… → i-0abc…).
  instance_ids = [for arn in var.instance_arns : element(split("/", arn), length(split("/", arn)) - 1)]
  state        = var.enabled ? "ENABLED" : "DISABLED"
}

# =============================================================================
# IAM role assumed by EventBridge Scheduler to call EC2 Start/StopInstances,
# scoped to exactly the provided instance ARNs.
# =============================================================================
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.app_name}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-scheduler-role"
    ManagedBy = "Terraform"
  })
}

data "aws_iam_policy_document" "perms" {
  statement {
    sid       = "StartStopInstances"
    effect    = "Allow"
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = var.instance_arns
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${var.app_name}-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.perms.json
}

# =============================================================================
# Two schedules — start and stop — via EventBridge Scheduler universal targets.
# =============================================================================
resource "aws_scheduler_schedule" "start" {
  name       = "${var.app_name}-start"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.start_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = local.instance_ids })
  }
}

resource "aws_scheduler_schedule" "stop" {
  name       = "${var.app_name}-stop"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.stop_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = local.instance_ids })
  }
}
