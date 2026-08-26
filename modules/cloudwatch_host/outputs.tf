output "log_group_name" {
  description = "Name of the created log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the created log group."
  value       = aws_cloudwatch_log_group.this.arn
}

output "alarm_arns" {
  description = "Map of alarm key => ARN (memory/disk present only when enabled)."
  value = merge(
    {
      cpu          = aws_cloudwatch_metric_alarm.cpu.arn
      status_check = aws_cloudwatch_metric_alarm.status_check.arn
    },
    var.create_memory_alarm ? { memory = aws_cloudwatch_metric_alarm.memory[0].arn } : {},
    var.create_disk_alarm ? { disk = aws_cloudwatch_metric_alarm.disk[0].arn } : {},
  )
}

output "host_absent_alarm_name" {
  description = "Name of the host-absent alarm (null unless create_host_absent_alarm). Feed this to the alarm_office_hours_gate module."
  value       = one(aws_cloudwatch_metric_alarm.host_absent[*].alarm_name)
}
