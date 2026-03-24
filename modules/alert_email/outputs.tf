output "sns_topic_arn" {
  description = "ARN of the SNS topic. Publish alerts here from any service."
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.alerts.name
}

output "lambda_function_arn" {
  description = "ARN of the email forwarder Lambda function."
  value       = aws_lambda_function.forwarder.arn
}

output "lambda_function_name" {
  description = "Name of the email forwarder Lambda function."
  value       = aws_lambda_function.forwarder.function_name
}
