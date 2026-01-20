output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Revision of the ECS task definition"
  value       = aws_ecs_task_definition.this.revision
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.task_execution_role.iam_role_arn
}

output "task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = module.task_execution_role.iam_role_name
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.task_role.iam_role_arn
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = module.task_role.iam_role_name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.arn
}

output "container_name" {
  description = "Name of the container in the task definition"
  value       = var.container_name
}
