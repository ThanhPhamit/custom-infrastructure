#
# CloudWatch metric alarms for RDS instances with SNS-backed Slack notifications
#

#
# CPU utilization (Notice) — informational alarm; publishes to the configured "notice" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization_notice" {
  alarm_name          = "${var.app_name}_rds_cpu_utilization_notice"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_cpu_utilization_notice_threshold
  alarm_description   = "RDS CPU Utilization"
  alarm_actions       = [var.chatbot_notice_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-cpu-utilization-notice"
    }
  )
}

#
# CPU utilization (Alert) — critical alarm; publishes to the configured "alert" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization_alert" {
  alarm_name          = "${var.app_name}_rds_cpu_utilization_alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_cpu_utilization_alert_threshold
  alarm_description   = "RDS CPU Utilization"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-cpu-utilization-alert"
    }
  )
}


#
# Freeable memory (Notice) — informational low-memory alarm; publishes to the configured "notice" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_notice" {
  alarm_name          = "${var.app_name}_rds_freeable_memory_notice"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_freeable_memory_notice_threshold
  alarm_description   = "RDS Freeable Memory is too low."
  alarm_actions       = [var.chatbot_notice_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-freeable-memory-notice"
    }
  )
}

#
# Freeable memory (Alert) — critical low-memory alarm; publishes to the configured "alert" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_alert" {
  alarm_name          = "${var.app_name}_rds_freeable_memory_alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_freeable_memory_alert_threshold
  alarm_description   = "RDS Freeable Memory is too low."
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-freeable-memory-alert"
    }
  )
}

#
# Free storage space (Notice) — informational low-storage alarm; publishes to the configured "notice" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_freeable_storage_space_notice" {
  alarm_name          = "${var.app_name}_rds_freeable_storage_space_notice"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_freeable_storage_space_notice_threshold
  alarm_description   = "RDS Freeable Storage Space is too low."
  alarm_actions       = [var.chatbot_notice_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-freeable-storage-space-notice"
    }
  )
}


#
# Free storage space (Alert) — critical low-storage alarm; publishes to the configured "alert" SNS topic (Slack)
#
resource "aws_cloudwatch_metric_alarm" "rds_freeable_storage_space_alert" {
  alarm_name          = "${var.app_name}_rds_freeable_storage_space_alert"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_rds_default_evaluation_periods
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.cw_alarm_rds_default_period
  statistic           = "Average"
  threshold           = var.cw_alarm_rds_freeable_storage_space_alert_threshold
  alarm_description   = "RDS Freeable Storage Space is too low."
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-freeable-storage-space-alert"
    }
  )
}
