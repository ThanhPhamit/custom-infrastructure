output "cluster_identifier" {
  description = "Identifier of the Aurora PostgreSQL cluster."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_arn" {
  description = "ARN of the Aurora PostgreSQL cluster."
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer (primary) endpoint of the Aurora cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster (load-balances across readers)."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Port on which the Aurora cluster accepts connections."
  value       = aws_rds_cluster.this.port
}

output "cluster_resource_id" {
  description = "Cluster resource ID, used in IAM database-authentication policy ARNs (rds-db:connect)."
  value       = aws_rds_cluster.this.cluster_resource_id
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret in Secrets Manager (null if not managed)."
  value       = try(aws_rds_cluster.this.master_user_secret[0].secret_arn, null)
}

output "security_group_id" {
  description = "ID of the security group attached to the Aurora cluster."
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group used by the Aurora cluster."
  value       = aws_db_subnet_group.this.name
}
