# Remark AI Tool Outputs

output "remark_ai_tool_ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.remark_ai_tool_ecr.repository_url
}

output "remark_ai_tool_db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret for database password"
  value       = aws_secretsmanager_secret.ecs_db_password.arn
}

output "remark_ai_tool_db_password_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.ecs_db_password.name
}

output "remark_ai_tool_vpc_endpoint_sg_id" {
  description = "Security Group ID for VPC Endpoints access - Add this to allowed_security_group_ids_for_vpc_endpoints"
  value       = aws_security_group.remark_ai_tool_vpc_endpoint.id
}
