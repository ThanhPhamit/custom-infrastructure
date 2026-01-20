output "task_failed_alarm_arn" {
  description = "ARN of the task failed alarm"
  value       = var.enable_task_failure_monitoring ? aws_cloudwatch_metric_alarm.ecs_task_failed[0].arn : null
}

output "cpu_high_alarm_arn" {
  description = "ARN of the CPU high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_task_cpu_high.arn
}

output "memory_high_alarm_arn" {
  description = "ARN of the memory high utilization alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_task_memory_high.arn
}

output "log_errors_alarm_arn" {
  description = "ARN of the log errors alarm"
  value       = var.enable_log_error_monitoring ? aws_cloudwatch_metric_alarm.ecs_task_log_errors_alarm[0].arn : null
}
