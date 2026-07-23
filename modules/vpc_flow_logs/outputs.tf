output "flow_log_id" {
  description = "ID of the VPC flow log."
  value       = aws_flow_log.this.id
}

output "log_group_name" {
  description = "CloudWatch Logs group receiving the flow logs (query here for network forensics)."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the flow-logs log group."
  value       = aws_cloudwatch_log_group.this.arn
}

output "iam_role_arn" {
  description = "ARN of the flow-logs delivery role."
  value       = aws_iam_role.this.arn
}
