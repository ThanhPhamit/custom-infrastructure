# CloudWatch Alarms for ECS Scheduled Tasks
# This module monitors critical metrics for ECS tasks running on a schedule

# ============================================
# TASK FAILURE MONITORING (Log-based)
# ============================================
# Monitors application logs for ERROR/Exception - triggers only on actual errors
# This detects when your Python app logs errors (logger.error, exceptions, etc.)

resource "aws_cloudwatch_log_metric_filter" "ecs_task_application_errors" {
  count          = var.enable_task_failure_monitoring ? 1 : 0
  name           = "${var.app_name}-ecs-task-application-errors"
  log_group_name = var.log_group_name

  # Pattern matches ERROR level logs and exceptions in application logs
  # This catches: logger.error(), logger.critical(), unhandled exceptions with traceback
  # Will NOT trigger on: logger.info("✅ Connection Test Completed Successfully")
  pattern = var.task_failure_log_pattern

  metric_transformation {
    name          = "${var.app_name}_ecs_task_failures"
    namespace     = "${var.app_name}/ECS/ScheduledTask"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_failed" {
  count               = var.enable_task_failure_monitoring ? 1 : 0
  alarm_name          = "${var.app_name}-ecs-scheduled-task-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.task_failed_evaluation_periods
  metric_name         = "${var.app_name}_ecs_task_failures"
  namespace           = "${var.app_name}/ECS/ScheduledTask"
  period              = var.task_failed_period
  statistic           = "Sum"
  threshold           = var.task_failed_threshold
  alarm_description   = "Alert when ECS scheduled task logs application errors"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-scheduled-task-failed"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.ecs_task_application_errors]
}

# CPU Utilization High Alert
resource "aws_cloudwatch_metric_alarm" "ecs_task_cpu_high" {
  alarm_name          = "${var.app_name}-ecs-scheduled-task-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.cpu_period
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "Alert when ECS scheduled task CPU utilization is too high"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-scheduled-task-cpu-high"
    }
  )
}

# Memory Utilization High Alert
resource "aws_cloudwatch_metric_alarm" "ecs_task_memory_high" {
  alarm_name          = "${var.app_name}-ecs-scheduled-task-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.memory_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.memory_period
  statistic           = "Average"
  threshold           = var.memory_high_threshold
  alarm_description   = "Alert when ECS scheduled task memory utilization is too high"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-scheduled-task-memory-high"
    }
  )
}

# Log Errors Detection
resource "aws_cloudwatch_log_metric_filter" "ecs_task_log_errors" {
  count          = var.enable_log_error_monitoring ? 1 : 0
  name           = "${var.app_name}-ecs-scheduled-task-log-errors"
  pattern        = var.log_error_pattern
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "${var.app_name}_ecs_scheduled_task_log_errors"
    namespace     = "${var.app_name}/ECS/ScheduledTask/LogErrors"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_log_errors_alarm" {
  count               = var.enable_log_error_monitoring ? 1 : 0
  alarm_name          = "${var.app_name}-ecs-scheduled-task-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.log_error_evaluation_periods
  metric_name         = "${var.app_name}_ecs_scheduled_task_log_errors"
  namespace           = "${var.app_name}/ECS/ScheduledTask/LogErrors"
  period              = var.log_error_period
  statistic           = "Sum"
  threshold           = var.log_error_threshold
  alarm_description   = "Alert when errors are detected in ECS scheduled task logs"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-scheduled-task-log-errors"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.ecs_task_log_errors]
}
