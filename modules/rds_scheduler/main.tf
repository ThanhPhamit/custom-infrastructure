data "aws_caller_identity" "current" {}

locals {
  # Derive DB identifiers from the ARNs (…:db:my-database → my-database). RDS ARNs are
  # colon-separated, unlike EC2's …:instance/i-0abc — that is the only shape difference from
  # ec2_scheduler, and the reason this is a sibling module rather than a flag on that one.
  db_identifiers = { for arn in var.db_instance_arns :
    element(split(":", arn), length(split(":", arn)) - 1) => arn
  }
  state = var.enabled ? "ENABLED" : "DISABLED"

  # Schedule names. A database is very often named after the application that owns it, so
  # "${app_name}-${identifier}-rds-start" repeats the prefix -- on a real stack whose app_name and DB
  # identifier were both 20 characters that produced a 51-character name, and EventBridge allows 64,
  # so a slightly longer pair fails at APPLY rather than at plan. Strip the repetition; when the
  # identifier IS the app name there is nothing left to disambiguate, so the suffix stands alone.
  name_part = { for id in keys(local.db_identifiers) :
    id => id == var.app_name ? "" : "-${trimprefix(trimprefix(id, "${var.app_name}-"), "${var.app_name}_")}"
  }
}

# =============================================================================
# IAM role assumed by EventBridge Scheduler to call RDS Start/StopDBInstance,
# scoped to exactly the provided DB ARNs.
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
  name               = "${var.app_name}-rds-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-rds-scheduler-role"
    ManagedBy = "Terraform"
  })
}

data "aws_iam_policy_document" "perms" {
  statement {
    sid       = "StartStopDBInstances"
    effect    = "Allow"
    actions   = ["rds:StartDBInstance", "rds:StopDBInstance"]
    resources = var.db_instance_arns
  }

  # DescribeDBInstances cannot be resource-scoped — the API ignores the resource element and
  # authorises on "*". Read-only and metadata-only, and the scheduler needs it to resolve state
  # before acting. Kept in its own statement so the scoped grant above stays obviously scoped.
  statement {
    sid       = "DescribeForStateCheck"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
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
  name   = "${var.app_name}-rds-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.perms.json
}

# =============================================================================
# Two schedules PER DATABASE. The RDS API takes ONE DbInstanceIdentifier per call — there is no
# batch form as there is for ec2:StartInstances — so this fans out with for_each rather than
# passing a list in a single target input.
# =============================================================================
resource "aws_scheduler_schedule" "start" {
  for_each = local.db_identifiers

  name       = "${var.app_name}${local.name_part[each.key]}-rds-start"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.start_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:startDBInstance"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ DbInstanceIdentifier = each.key })

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
  for_each = local.db_identifiers

  name       = "${var.app_name}${local.name_part[each.key]}-rds-stop"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.stop_expression
  schedule_expression_timezone = var.timezone
  state                        = local.state
  kms_key_arn                  = var.kms_key_arn

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:stopDBInstance"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ DbInstanceIdentifier = each.key })

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
