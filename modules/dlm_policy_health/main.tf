locals {
  # A DLM policy leaving ENABLED is the signal: ERROR means it broke, DISABLED means someone turned
  # backups off. Both deserve a message; neither produces a CloudWatch metric.
  dlm_pattern = {
    source        = ["aws.dlm"]
    "detail-type" = ["DLM Policy State Change"]
    detail = merge(
      { state = [{ "anything-but" = "ENABLED" }] },
      length(var.policy_ids) > 0 ? { policy_id = var.policy_ids } : {},
    )
  }

  # A human turning backups off does NOT produce a "DLM Policy State Change" event -- measured
  # 2026-08-27 by disabling a live policy and watching the rule never fire. DLM emits that event only
  # when IT moves a policy to ERROR. The API call is visible through CloudTrail, though, which is the
  # same route the account's CloudTrail-tamper rule already uses.
  api_pattern = {
    source        = ["aws.dlm"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["dlm.amazonaws.com"]
      eventName   = ["UpdateLifecyclePolicy", "DeleteLifecyclePolicy"]
    }
  }

  snapshot_pattern = {
    source        = ["aws.ec2"]
    "detail-type" = ["EBS Snapshot Notification"]
    detail        = { result = ["failed"] }
  }
}

resource "aws_cloudwatch_event_rule" "dlm_policy_state" {
  name          = "${var.app_name}-dlm-policy-unhealthy"
  description   = "A DLM lifecycle policy left the ENABLED state -- it errored, or backups were switched off."
  event_pattern = jsonencode(local.dlm_pattern)

  tags = merge(var.tags, {
    Name      = "${var.app_name}-dlm-policy-unhealthy"
    ManagedBy = "Terraform"
  })
}

resource "aws_cloudwatch_event_target" "dlm_policy_state" {
  rule      = aws_cloudwatch_event_rule.dlm_policy_state.name
  target_id = "sns"
  arn       = var.sns_topic_arn
}

resource "aws_cloudwatch_event_rule" "dlm_api_change" {
  count = var.watch_api_changes ? 1 : 0

  name          = "${var.app_name}-dlm-policy-changed"
  description   = "Someone updated or deleted a DLM lifecycle policy. Catches backups being switched off, which the DLM state-change event does NOT report."
  event_pattern = jsonencode(local.api_pattern)

  tags = merge(var.tags, {
    Name      = "${var.app_name}-dlm-policy-changed"
    ManagedBy = "Terraform"
  })
}

resource "aws_cloudwatch_event_target" "dlm_api_change" {
  count = var.watch_api_changes ? 1 : 0

  rule      = aws_cloudwatch_event_rule.dlm_api_change[0].name
  target_id = "sns"
  arn       = var.sns_topic_arn
}

resource "aws_cloudwatch_event_rule" "snapshot_failed" {
  count = var.watch_snapshot_failures ? 1 : 0

  name          = "${var.app_name}-ebs-snapshot-failed"
  description   = "An EBS snapshot finished with result=failed. Account-wide, not limited to DLM-created snapshots."
  event_pattern = jsonencode(local.snapshot_pattern)

  tags = merge(var.tags, {
    Name      = "${var.app_name}-ebs-snapshot-failed"
    ManagedBy = "Terraform"
  })
}

resource "aws_cloudwatch_event_target" "snapshot_failed" {
  count = var.watch_snapshot_failures ? 1 : 0

  rule      = aws_cloudwatch_event_rule.snapshot_failed[0].name
  target_id = "sns"
  arn       = var.sns_topic_arn
}
