output "role_arn" {
  description = "ARN of the IAM role EventBridge Scheduler assumes to gate the alarms."
  value       = aws_iam_role.gate.arn
}

output "schedule_names" {
  description = "Names of the gate schedules: disarm, arm, and one reset per gated alarm."
  value = concat(
    [aws_scheduler_schedule.disarm.name, aws_scheduler_schedule.arm.name],
    [for s in aws_scheduler_schedule.reset : s.name],
  )
}

output "gated_alarm_arns" {
  description = "The ARNs the IAM policy is scoped to -- use it to confirm the gate can only touch the alarms it was given."
  value       = local.alarm_arns
}
