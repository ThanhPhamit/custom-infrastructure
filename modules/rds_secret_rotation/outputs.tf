output "rotation_lambda_name" {
  description = "RDS rotation lambda function name"
  value       = data.aws_lambda_function.rotation.function_name
}

output "rotation_lambda_arn" {
  description = "RDS rotation lambda function ARN"
  value       = data.aws_lambda_function.rotation.arn
}

output "rotation_enabled_secret_arn" {
  description = "Secret ARN with enabled automatic rotation"
  value       = aws_secretsmanager_secret_rotation.this.secret_id
}
