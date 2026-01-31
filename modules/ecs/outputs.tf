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
