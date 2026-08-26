locals {
  dims = { InstanceId = var.instance_id }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.log_kms_key_id

  tags = merge(var.tags, {
    Name      = var.log_group_name
    ManagedBy = "Terraform"
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.app_name}-cpu-high"
  alarm_description   = "EC2 CPUUtilization >= ${var.cpu_threshold}% on ${var.instance_id}"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  dimensions          = local.dims
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.cpu_threshold
  period              = var.period
  evaluation_periods  = var.evaluation_periods
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = merge(var.tags, { ManagedBy = "Terraform" })
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.app_name}-status-check-failed"
  alarm_description   = "EC2 StatusCheckFailed (system or instance) on ${var.instance_id}"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  dimensions          = local.dims
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 60
  evaluation_periods  = 2

  # "breaching" is right for a host that is supposed to be up 24/7: StatusCheckFailed simply STOPS
  # reporting when an instance is stopped or terminated, so absence of data is the only signal that
  # the machine is gone. It is WRONG for a host on a start/stop schedule -- every scheduled stop
  # would page. Set "notBreaching" there: an instance that is running but broken still publishes
  # StatusCheckFailed = 1 and still alarms; what you give up is detecting a machine that vanished.
  treat_missing_data = var.status_check_treat_missing_data

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = merge(var.tags, { ManagedBy = "Terraform" })
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  count = var.create_memory_alarm ? 1 : 0

  alarm_name          = "${var.app_name}-memory-high"
  alarm_description   = "CWAgent mem_used_percent >= ${var.memory_threshold}% on ${var.instance_id} (RAM pressure)"
  namespace           = var.cwagent_namespace
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  dimensions          = local.dims
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.memory_threshold
  period              = var.period
  evaluation_periods  = var.evaluation_periods
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = merge(var.tags, { ManagedBy = "Terraform" })
}

resource "aws_cloudwatch_metric_alarm" "disk" {
  count = var.create_disk_alarm ? 1 : 0

  alarm_name          = "${var.app_name}-disk-high"
  alarm_description   = "CWAgent disk_used_percent (root fs) >= ${var.disk_threshold}% on ${var.instance_id}"
  namespace           = var.cwagent_namespace
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  dimensions          = local.dims
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.disk_threshold
  period              = var.period
  evaluation_periods  = var.evaluation_periods
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = merge(var.tags, { ManagedBy = "Terraform" })
}

# =============================================================================
# "The host should be up and it is not" -- the blind spot of the alarm above.
#
# StatusCheckFailed stops publishing entirely when an instance is stopped, so a scheduled host has
# to choose: notBreaching (silent on a scheduled stop, and equally silent when a start FAILS) or
# breaching (catches the failed start, pages every night). Neither is right on its own.
#
# The answer is two alarms with different missing-data policies. This one takes "breaching" and is
# armed only during the hours the host is meant to be running; the one above takes "notBreaching"
# and stays armed around the clock for a host that is running but broken.
#
# Measured 2026-08-26 on lg-autoflow prod: the scheduler's StartInstances call returned success, EC2
# failed the launch internally (StateTransitionReason Server.InternalError), the host never booted
# -- no boot record, zero CPU datapoints -- and nothing alarmed for nine hours, because the only
# host alarm was notBreaching for exactly the reason written above it.
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "host_absent" {
  count = var.create_host_absent_alarm ? 1 : 0

  alarm_name          = "${var.app_name}-host-absent"
  alarm_description   = "No StatusCheckFailed data for ${var.instance_id} during the hours it is scheduled to run -- the instance is stopped, terminated, or failed to launch."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  dimensions          = local.dims
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 60
  evaluation_periods  = 2

  treat_missing_data = "breaching"

  alarm_actions = [var.sns_topic_arn]

  # Empty on purpose -- see create_host_absent_alarm. The gate's morning reset is an ALARM -> OK
  # transition, and an ok_action here would post that reset to Slack every working day.
  ok_actions = []

  # The gate flips actions_enabled off and on through the CloudWatch API. Terraform would otherwise
  # plan it back to true on every apply and silently re-arm the alarm in the middle of the night.
  actions_enabled = true
  lifecycle {
    ignore_changes = [actions_enabled]
  }

  tags = merge(var.tags, { ManagedBy = "Terraform" })
}
