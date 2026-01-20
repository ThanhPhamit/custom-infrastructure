output "failed_invocations_alarm_arn" {
  description = "ARN of the failed invocations alarm"
  value       = aws_cloudwatch_metric_alarm.eventbridge_failed_invocations.arn
}

output "throttled_rules_alarm_arn" {
  description = "ARN of the throttled rules alarm"
  value       = aws_cloudwatch_metric_alarm.eventbridge_throttled_rules.arn
}

output "invocations_low_alarm_arn" {
  description = "ARN of the invocations low alarm"
  value       = var.enable_invocations_monitoring ? aws_cloudwatch_metric_alarm.eventbridge_invocations_low[0].arn : null
}

output "dlq_messages_alarm_arn" {
  description = "ARN of the DLQ messages alarm"
  value       = var.enable_dlq_monitoring ? aws_cloudwatch_metric_alarm.eventbridge_dlq_messages[0].arn : null
}
