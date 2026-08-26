output "alarm_name" {
  description = "Name of the no-healthy-host alarm. Feed this to the alarm_office_hours_gate module when the target runs on a schedule."
  value       = aws_cloudwatch_metric_alarm.no_healthy_host.alarm_name
}

output "alarm_arn" {
  description = "ARN of the no-healthy-host alarm."
  value       = aws_cloudwatch_metric_alarm.no_healthy_host.arn
}
