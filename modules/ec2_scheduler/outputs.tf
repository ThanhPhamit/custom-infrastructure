output "start_schedule_arn" {
  description = "ARN of the start schedule."
  value       = aws_scheduler_schedule.start.arn
}

output "stop_schedule_arn" {
  description = "ARN of the stop schedule."
  value       = aws_scheduler_schedule.stop.arn
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role EventBridge Scheduler assumes to start/stop the instances."
  value       = aws_iam_role.scheduler.arn
}

output "managed_instance_ids" {
  description = "Instance IDs the schedules act on (derived from instance_arns)."
  value       = local.instance_ids
}
