output "lambda_function_name" {
  description = "Lambda function name for rotation rollout"
  value       = module.rotation_rollout_lambda.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN for rotation rollout"
  value       = module.rotation_rollout_lambda.lambda_function_arn
}

output "eventbridge_rule_arn" {
  description = "EventBridge rule ARN listening for Rotation Succeeded"
  value       = aws_cloudwatch_event_rule.rotation_succeeded.arn
}
