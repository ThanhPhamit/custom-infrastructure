output "rule_id" {
  description = "ID of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.id
}

output "rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.name
}

output "eventbridge_role_arn" {
  description = "ARN of the EventBridge IAM role"
  value       = module.eventbridge_role.iam_role_arn
}

output "eventbridge_role_name" {
  description = "Name of the EventBridge IAM role"
  value       = module.eventbridge_role.iam_role_name
}

output "target_id" {
  description = "ID of the EventBridge target"
  value       = local.is_ecs_target ? (length(aws_cloudwatch_event_target.ecs) > 0 ? aws_cloudwatch_event_target.ecs[0].target_id : null) : (length(aws_cloudwatch_event_target.lambda) > 0 ? aws_cloudwatch_event_target.lambda[0].target_id : null)
}
