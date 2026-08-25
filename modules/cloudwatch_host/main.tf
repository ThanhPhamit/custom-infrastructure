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
