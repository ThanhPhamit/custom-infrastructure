output "start_schedule_arns" {
  description = "ARNs of the start schedules, keyed by DB identifier."
  value       = { for k, s in aws_scheduler_schedule.start : k => s.arn }
}

output "stop_schedule_arns" {
  description = "ARNs of the stop schedules, keyed by DB identifier."
  value       = { for k, s in aws_scheduler_schedule.stop : k => s.arn }
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role EventBridge Scheduler assumes to start/stop the databases."
  value       = aws_iam_role.scheduler.arn
}

output "managed_db_identifiers" {
  description = "DB instance identifiers the schedules act on (derived from db_instance_arns)."
  value       = keys(local.db_identifiers)
}
