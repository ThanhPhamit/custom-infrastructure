data "aws_caller_identity" "current" {}

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

    # Confused-deputy guard. scheduler.amazonaws.com is a GLOBAL service principal: without this,
    # the trust says "any EventBridge Scheduler may assume this role", including one in an account
    # that is not yours.
    #
    # SourceAccount ONLY — do not add an ArnLike on aws:SourceArn here. It looks tighter and it
    # breaks the module: EventBridge Scheduler validates that it can assume the role at
    # CreateSchedule time, and at that moment the schedule does not exist yet, so there is no
    # SourceArn to match. CreateSchedule then fails with "The execution role you provide must allow
    # AWS EventBridge Scheduler to assume the role" — measured 2026-08-25, and it fails for a
    # schedule name INSIDE the pattern just as it does for one outside, which is what rules out a
    # simple pattern mistake. Existing schedules keep working (they were created before the
    # condition existed), so the damage only appears the next time someone applies from scratch.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
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

  # Only granted when a dead-letter queue is actually configured — an unused SendMessage grant is
  # just a permission nobody audits.
  dynamic "statement" {
    for_each = var.dead_letter_arn == null ? [] : [var.dead_letter_arn]
    content {
      sid       = "SendFailedInvocationToDLQ"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [statement.value]
    }
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
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = local.instance_ids })

    retry_policy {
      maximum_retry_attempts       = var.retry_maximum_attempts
      maximum_event_age_in_seconds = var.retry_maximum_event_age_seconds
    }

    dynamic "dead_letter_config" {
      for_each = var.dead_letter_arn == null ? [] : [var.dead_letter_arn]
      content {
        arn = dead_letter_config.value
      }
    }
  }
}

# Retry schedules. Same target, same input, a few minutes later -- see additional_start_expressions.
# for_each over the expression itself keeps the address stable when the list is reordered.
resource "aws_scheduler_schedule" "start_retry" {
  for_each = toset(var.additional_start_expressions)

  name       = "${var.app_name}-start-retry-${substr(md5(each.value), 0, 8)}"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = each.value
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = local.instance_ids })

    retry_policy {
      maximum_retry_attempts       = var.retry_maximum_attempts
      maximum_event_age_in_seconds = var.retry_maximum_event_age_seconds
    }

    dynamic "dead_letter_config" {
      for_each = var.dead_letter_arn == null ? [] : [var.dead_letter_arn]
      content {
        arn = dead_letter_config.value
      }
    }
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
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = local.instance_ids })

    retry_policy {
      maximum_retry_attempts       = var.retry_maximum_attempts
      maximum_event_age_in_seconds = var.retry_maximum_event_age_seconds
    }

    dynamic "dead_letter_config" {
      for_each = var.dead_letter_arn == null ? [] : [var.dead_letter_arn]
      content {
        arn = dead_letter_config.value
      }
    }
  }
}
