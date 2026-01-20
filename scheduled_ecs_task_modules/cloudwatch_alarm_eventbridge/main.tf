# CloudWatch Alarms for EventBridge Scheduler
# This module monitors critical metrics for EventBridge rules and scheduled events

# Rule Execution Failed - Monitors failed rule invocations
resource "aws_cloudwatch_metric_alarm" "eventbridge_failed_invocations" {
  alarm_name          = "${var.app_name}-eventbridge-failed-invocations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.failed_invocations_evaluation_periods
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = var.failed_invocations_period
  statistic           = "Sum"
  threshold           = var.failed_invocations_threshold
  alarm_description   = "Alert when EventBridge rule fails to invoke target"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    RuleName = var.rule_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-eventbridge-failed-invocations"
    }
  )
}

# Throttled Rules - Monitors when rules are throttled
resource "aws_cloudwatch_metric_alarm" "eventbridge_throttled_rules" {
  alarm_name          = "${var.app_name}-eventbridge-throttled-rules"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.throttled_rules_evaluation_periods
  metric_name         = "ThrottledRules"
  namespace           = "AWS/Events"
  period              = var.throttled_rules_period
  statistic           = "Sum"
  threshold           = var.throttled_rules_threshold
  alarm_description   = "Alert when EventBridge rule is throttled"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    RuleName = var.rule_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-eventbridge-throttled-rules"
    }
  )
}

# Invocations Count Low - Detects when scheduled events stop firing
resource "aws_cloudwatch_metric_alarm" "eventbridge_invocations_low" {
  count               = var.enable_invocations_monitoring ? 1 : 0
  alarm_name          = "${var.app_name}-eventbridge-invocations-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.invocations_low_evaluation_periods
  metric_name         = "Invocations"
  namespace           = "AWS/Events"
  period              = var.invocations_low_period
  statistic           = "Sum"
  threshold           = var.invocations_low_threshold
  alarm_description   = "Alert when EventBridge rule stops triggering (no invocations detected)"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    RuleName = var.rule_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-eventbridge-invocations-low"
    }
  )
}

# Dead Letter Queue Messages - Monitors messages sent to DLQ
resource "aws_cloudwatch_metric_alarm" "eventbridge_dlq_messages" {
  count               = var.enable_dlq_monitoring ? 1 : 0
  alarm_name          = "${var.app_name}-eventbridge-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.dlq_messages_evaluation_periods
  metric_name         = "NumberOfMessagesReceived"
  namespace           = "AWS/SQS"
  period              = var.dlq_messages_period
  statistic           = "Sum"
  threshold           = var.dlq_messages_threshold
  alarm_description   = "Alert when messages are sent to EventBridge Dead Letter Queue"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-eventbridge-dlq-messages"
    }
  )
}
