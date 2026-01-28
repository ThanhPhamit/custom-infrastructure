#--------------------------------------------------------------
# Primary Instance Outputs
#--------------------------------------------------------------
output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.primary.id
}

output "db_instance_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.primary.identifier
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.primary.arn
}

output "db_endpoint" {
  description = "Endpoint of the RDS instance (hostname:port)"
  value       = aws_db_instance.primary.endpoint
}

output "db_hostname" {
  description = "Hostname of the RDS instance (without port)"
  value       = split(":", aws_db_instance.primary.endpoint)[0]
}

output "db_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.primary.port
}

output "db_name" {
  description = "Name of the default database"
  value       = aws_db_instance.primary.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.primary.username
}

output "db_engine" {
  description = "Database engine"
  value       = aws_db_instance.primary.engine
}

output "db_engine_version" {
  description = "Database engine version"
  value       = aws_db_instance.primary.engine_version
}

#--------------------------------------------------------------
# Replica Outputs
#--------------------------------------------------------------
output "replica_instance_id" {
  description = "ID of the read replica instance"
  value       = var.create_replica ? aws_db_instance.replica[0].id : null
}

output "replica_instance_identifier" {
  description = "Identifier of the read replica instance"
  value       = var.create_replica ? aws_db_instance.replica[0].identifier : null
}

output "replica_endpoint" {
  description = "Endpoint of the read replica (hostname:port)"
  value       = var.create_replica ? aws_db_instance.replica[0].endpoint : null
}

output "replica_hostname" {
  description = "Hostname of the read replica (without port)"
  value       = var.create_replica ? split(":", aws_db_instance.replica[0].endpoint)[0] : null
}

#--------------------------------------------------------------
# Security Outputs
#--------------------------------------------------------------
output "security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group (created internally or provided externally)"
  value       = local.db_subnet_group_name
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group (only when created internally, null when provided externally)"
  value       = var.db_subnet_group_name == null ? aws_db_subnet_group.db[0].id : null
}

output "db_subnet_group_arn" {
  description = "ARN of the DB subnet group (only when created internally, null when provided externally)"
  value       = var.db_subnet_group_name == null ? aws_db_subnet_group.db[0].arn : null
}

#--------------------------------------------------------------
# Password/Secret Outputs
#--------------------------------------------------------------
output "password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the password (null if password was provided)"
  value       = local.use_generated_password ? aws_secretsmanager_secret.rds_password[0].arn : null
}

output "password_secret_name" {
  description = "Name of the Secrets Manager secret containing the password"
  value       = local.use_generated_password ? aws_secretsmanager_secret.rds_password[0].name : null
}

#--------------------------------------------------------------
# Monitoring Outputs
#--------------------------------------------------------------
output "monitoring_role_arn" {
  description = "ARN of the enhanced monitoring IAM role"
  value       = var.monitoring_interval > 0 ? module.rds_monitoring_role[0].iam_role_arn : null
}

#--------------------------------------------------------------
# S3 Integration Outputs
#--------------------------------------------------------------
output "s3_export_role_arn" {
  description = "ARN of the S3 export IAM role"
  value       = var.enable_s3_integration ? module.rds_s3_export_role[0].iam_role_arn : null
}

output "s3_import_role_arn" {
  description = "ARN of the S3 import IAM role"
  value       = var.enable_s3_integration ? module.rds_s3_import_role[0].iam_role_arn : null
}

#--------------------------------------------------------------
# Connection String Outputs (for convenience)
#--------------------------------------------------------------
output "connection_string_template" {
  description = "Template connection string (password not included)"
  value       = "${var.engine}://${aws_db_instance.primary.username}:<PASSWORD>@${split(":", aws_db_instance.primary.endpoint)[0]}:${aws_db_instance.primary.port}/${aws_db_instance.primary.db_name}"
}
