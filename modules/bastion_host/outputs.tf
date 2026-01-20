output "bastion_instance_id" {
  description = "ID of the bastion host instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = aws_instance.bastion.private_ip
}

output "bastion_security_group_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "elastic_ip" {
  description = "Elastic IP address of the bastion host (if created)"
  value       = var.create_eip ? aws_eip.bastion[0].public_ip : null
}

output "ssh_command" {
  description = "SSH command to connect to the bastion host"
  value       = "ssh -i /path/to/your-key.pem ec2-user@${var.create_eip ? aws_eip.bastion[0].public_ip : aws_instance.bastion.public_ip}"
}

output "mysql_connection_example" {
  description = "Example MySQL connection command from bastion host"
  value       = "mysql -h <rds-endpoint> -u admin -p focuson"
}

output "scheduler_enabled" {
  description = "Whether the scheduler is enabled for the bastion host"
  value       = var.enable_scheduler
}

output "scheduler_lambda_function_arn" {
  description = "ARN of the Lambda function used for scheduling (if scheduler is enabled)"
  value       = var.enable_scheduler ? module.scheduler_lambda[0].lambda_function_arn : null
}

output "scheduler_lambda_function_name" {
  description = "Name of the Lambda function used for scheduling (if scheduler is enabled)"
  value       = var.enable_scheduler ? module.scheduler_lambda[0].lambda_function_name : null
}

output "scheduler_start_rule_arn" {
  description = "ARN of the EventBridge start rule (if scheduler is enabled)"
  value       = var.enable_scheduler ? aws_cloudwatch_event_rule.start_schedule[0].arn : null
}

output "scheduler_stop_rule_arn" {
  description = "ARN of the EventBridge stop rule (if scheduler is enabled)"
  value       = var.enable_scheduler ? aws_cloudwatch_event_rule.stop_schedule[0].arn : null
}

output "scheduler_tag_configuration" {
  description = "Tag configuration for the scheduler"
  value = var.enable_scheduler ? {
    tag_key   = "BastionScheduler"
    tag_value = local.scheduler_tag_value
  } : null
}

output "scheduler_cron_expressions" {
  description = "Cron expressions used for scheduling"
  value = var.enable_scheduler ? {
    start_cron = var.scheduler_start_cron
    stop_cron  = var.scheduler_stop_cron
  } : null
}
