output "instance_absent_alarm_name" {
  description = "Name of the instance-absent alarm (null unless create_instance_absent_alarm). Feed this to the alarm_office_hours_gate module."
  value       = one(aws_cloudwatch_metric_alarm.rds_instance_absent[*].alarm_name)
}
