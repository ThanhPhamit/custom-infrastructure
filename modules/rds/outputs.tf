output "rds_instance_id" {
  description = "ID of the RDS MySQL instance."
  value       = aws_db_instance.db.id
}

output "rds_endpoint" {
  description = "Endpoint of the RDS MySQL instance."
  value       = aws_db_instance.db.endpoint
}

output "rds_endpoint_hostname" {
  description = "Hostname of the RDS MySQL instance (without port)."
  value       = split(":", aws_db_instance.db.endpoint)[0]
}

output "rds_arn" {
  description = "ARN of the RDS MySQL instance."
  value       = aws_db_instance.db.arn
}

output "rds_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the RDS password"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "rds_database_name" {
  description = "Name of the RDS database."
  value       = aws_db_instance.db.db_name
}

output "rds_username" {
  description = "Username for the RDS database."
  value       = aws_db_instance.db.username
}

output "rds_port" {
  description = "Port of the RDS MySQL instance."
  value       = aws_db_instance.db.port
}
