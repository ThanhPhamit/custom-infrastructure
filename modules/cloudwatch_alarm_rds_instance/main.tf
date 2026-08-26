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

#
# Instance absent — "the database should be running right now and it is not there at all".
#
# There is no RDS metric for "instance is stopped", so this asks the question the only way
# CloudWatch allows: take a metric the instance publishes every 60 s while it lives, pick a
# condition real data can never satisfy, and let treat_missing_data do the work. SampleCount on
# CPUUtilization is exactly 1 per 60 s period while the instance runs (measured on
# prod-tyo-lg-autoflow, 2026-08-26: eleven consecutive periods, SampleCount 1.0, no gaps), so
# "< 1" is unreachable with data present and the alarm can only fire on absence.
#
# Why this exists: on 2026-08-26 the EC2 host failed to start and nothing alarmed for nine hours.
# RDS carries the same hole and it is worse -- the app host still boots, /healthz still returns 200
# because it never touches the database, so the site reads green while being unusable.
#
resource "aws_cloudwatch_metric_alarm" "rds_instance_absent" {
  count = var.create_instance_absent_alarm ? 1 : 0

  alarm_name          = "${var.app_name}_rds_absent"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "No AWS/RDS metrics for ${var.rds_db_instance_identifier} during the hours it is scheduled to run -- the instance is stopped, deleted, or failed to start."

  treat_missing_data = "breaching"

  alarm_actions = [var.chatbot_alert_sns_topic_arn]

  # Empty on purpose -- see create_instance_absent_alarm.
  ok_actions = []

  # The gate flips actions_enabled through the CloudWatch API; without this Terraform plans it back
  # to true on every apply and silently re-arms the alarm overnight.
  actions_enabled = true
  lifecycle {
    ignore_changes = [actions_enabled]
  }

  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-absent"
    }
  )
}

#
# Schedule overrun — the database is still running when it should have stopped.
#
# Companion to rds_instance_absent: that one costs availability, this one costs money and is
# invisible everywhere else. A stop whose API call succeeded but whose instance stayed up produces
# no error, no DLQ message, and no alarm — only a larger bill, weeks later.
#
# Counting, not sampling: CPUUtilization publishes one datapoint per minute while the instance lives
# (verified on a live db.t4g.micro, 2026-08-26), so the daily SampleCount is the minutes it ran.
# The alarm is blind to WHEN it ran, only to HOW LONG — so it needs no office-hours gate.
#
resource "aws_cloudwatch_metric_alarm" "rds_schedule_overrun" {
  count = var.create_schedule_overrun_alarm ? 1 : 0

  alarm_name          = "${var.app_name}_rds_schedule_overrun"
  alarm_description   = "DB instance ${var.rds_db_instance_identifier} ran more than ${var.schedule_overrun_max_minutes_per_day} minutes in a day -- a scheduled stop did not take effect. Cost leak, not an outage."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "SampleCount"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.schedule_overrun_max_minutes_per_day
  period              = 86400
  evaluation_periods  = 1

  # Absence is the good case: a full weekend produces no datapoints at all.
  treat_missing_data = "notBreaching"

  alarm_actions = [var.chatbot_alert_sns_topic_arn]
  ok_actions    = []

  dimensions = {
    DBInstanceIdentifier = var.rds_db_instance_identifier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-schedule-overrun"
    }
  )
}
