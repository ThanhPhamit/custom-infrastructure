# =============================================================================
# IAM role assumed by EventBridge Scheduler to arm / disarm / reset the given alarms.
# =============================================================================
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    # SourceAccount ONLY -- do NOT add an ArnLike on aws:SourceArn. Scheduler validates that it can
    # assume the role at CreateSchedule time, when the schedule does not exist yet and there is no
    # SourceArn to match; the create then fails with "The execution role you provide must allow AWS
    # EventBridge Scheduler to assume the role", including for names inside the pattern. Measured
    # 2026-08-25 on the ec2_scheduler role in this account.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "gate" {
  name               = "${var.app_name}-alarm-gate-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-alarm-gate-role"
    ManagedBy = "Terraform"
  })
}

data "aws_iam_policy_document" "perms" {
  statement {
    sid    = "GateAlarmActions"
    effect = "Allow"
    actions = [
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:SetAlarmState",
    ]
    resources = local.alarm_arns
  }

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

resource "aws_iam_role_policy" "gate" {
  name   = "${var.app_name}-alarm-gate"
  role   = aws_iam_role.gate.id
  policy = data.aws_iam_policy_document.perms.json
}

# =============================================================================
# Three schedules. The ORDER of the morning pair is load-bearing -- see arm_expression.
#   disarm -> DisableAlarmActions, before the resource stops
#   arm    -> EnableAlarmActions,  after the resource starts (silent: not a state transition)
#   reset  -> SetAlarmState(OK),   after arm (silent: ok_actions is empty), so the NEXT evaluation
#             produces a real OK -> ALARM transition when the resource is not there
# =============================================================================
resource "aws_scheduler_schedule" "disarm" {
  name       = "${var.app_name}-alarm-disarm"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.disarm_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:cloudwatch:disableAlarmActions"
    role_arn = aws_iam_role.gate.arn
    input    = jsonencode({ AlarmNames = var.alarm_names })

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

resource "aws_scheduler_schedule" "arm" {
  name       = "${var.app_name}-alarm-arm"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.arm_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:cloudwatch:enableAlarmActions"
    role_arn = aws_iam_role.gate.arn
    input    = jsonencode({ AlarmNames = var.alarm_names })

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

# SetAlarmState takes ONE alarm per call (AlarmName), unlike the two action APIs above which take a
# list (AlarmNames) -- hence for_each here and a single schedule there.
resource "aws_scheduler_schedule" "reset" {
  for_each = toset(var.alarm_names)

  name       = local.reset_names[each.key]
  group_name = "default"

  lifecycle {
    precondition {
      condition     = length(local.reset_names[each.key]) <= 64
      error_message = "Reset schedule name for alarm '${each.key}' exceeds the 64-character EventBridge Scheduler limit. Shorten the alarm name or app_name."
    }
  }

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.reset_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:cloudwatch:setAlarmState"
    role_arn = aws_iam_role.gate.arn
    input = jsonencode({
      AlarmName   = each.value
      StateValue  = "OK"
      StateReason = var.reset_state_reason
    })

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
