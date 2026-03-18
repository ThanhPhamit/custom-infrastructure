output "service_name" {
  value = aws_ecs_service.ecs_service.name
}

output "lb_target_group_blue_name" {
  value = aws_lb_target_group.target_group_blue.name
}

output "lb_target_group_blue_arn_suffix" {
  value = aws_lb_target_group.target_group_blue.arn_suffix
}

output "lb_target_group_green_name" {
  value = aws_lb_target_group.target_group_green.name
}

output "lb_target_group_green_arn_suffix" {
  value = aws_lb_target_group.target_group_green.arn_suffix
}

output "task_definition_arn" {
  description = "The ARN of the task definition including revision number"
  value       = aws_ecs_task_definition.task_definition.arn
}

output "task_definition_family" {
  description = "The family of the task definition"
  value       = aws_ecs_task_definition.task_definition.family
}

output "task_definition_revision" {
  description = "The revision of the task definition"
  value       = aws_ecs_task_definition.task_definition.revision
}

output "ecs_task_role_arn" {
  value = module.ecs_task_role.iam_role_arn
}

output "ecs_task_execution_role_arn" {
  value = module.ecs_task_execution_role.iam_role_arn
}

output "ecs_cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for the ECS service"
  value       = aws_cloudwatch_log_group.log[0].name
}

output "ecs_security_group_id" {
  description = "The ID of the ECS security group"
  value       = var.ecs_security_group_id
}

output "lb_target_group_blue_arn" {
  value = aws_lb_target_group.target_group_blue.arn
}

output "lb_target_group_green_arn" {
  value = aws_lb_target_group.target_group_green.arn
}

output "lb_listener_tcp_prod_arn" {
  value = var.load_balancer_type == "nlb" ? aws_lb_listener.nlb_prod[0].arn : var.http_prod_listener_arn
}

output "lb_listener_tcp_test_arn" {
  value = var.load_balancer_type == "nlb" ? aws_lb_listener.nlb_test[0].arn : var.http_test_listener_arn
}

# =============================================================================
# Consolidated App Runtime Secret ARN (single secret)
# =============================================================================

output "app_runtime_secret_arn" {
  description = "ARN of consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

# Backward-compatible outputs now point to the same consolidated secret ARN.
output "admin_secret_key_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "jwt_secret_key_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "jwt_refresh_secret_key_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "crypto_secret_key_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "secret_key_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "gmo_site_pass_secret_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "gmo_shop_pass_secret_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}

output "twilio_auth_token_secret_arn" {
  description = "ARN of the consolidated app runtime secret in Secrets Manager"
  value       = aws_secretsmanager_secret.app_runtime_secrets.arn
}
