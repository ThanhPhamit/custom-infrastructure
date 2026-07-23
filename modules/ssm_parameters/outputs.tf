output "parameter_arns" {
  description = "Map of short-name => parameter ARN."
  value       = { for k, p in aws_ssm_parameter.this : k => p.arn }
}

output "parameter_names" {
  description = "List of full parameter names created."
  value       = [for p in aws_ssm_parameter.this : p.name]
}

output "path_prefix" {
  description = "The common path prefix (scope IAM ssm:GetParameter* to <path_prefix>/*)."
  value       = var.path_prefix
}
