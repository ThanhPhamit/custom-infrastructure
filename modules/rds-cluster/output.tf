# Primary RDS cluster outputs
output "primary_db_cluster_endpoint" {
  description = "The endpoint of the primary RDS cluster"
  value       = aws_rds_cluster.primary.endpoint
}

output "primary_db_cluster_reader_endpoint" {
  description = "The reader endpoint of the primary RDS cluster"
  value       = aws_rds_cluster.primary.reader_endpoint
}

output "primary_db_cluster_id" {
  description = "The ID of the primary RDS cluster"
  value       = aws_rds_cluster.primary.id
}

output "primary_db_instance_identifiers" {
  description = "The identifiers of the primary RDS cluster instances"
  value       = [for instance in aws_rds_cluster_instance.primary : instance.id]
}

output "primary_db_instance_endpoints" {
  description = "The endpoints of the primary RDS cluster instances"
  value       = [for instance in aws_rds_cluster_instance.primary : instance.endpoint]
}

# Secondary RDS cluster outputs
output "secondary_db_cluster_endpoint" {
  description = "The endpoint of the secondary RDS cluster"
  value       = var.setup_globaldb ? aws_rds_cluster.secondary.endpoint : ""
}

output "secondary_db_cluster_reader_endpoint" {
  description = "The reader endpoint of the secondary RDS cluster"
  value       = var.setup_globaldb ? aws_rds_cluster.secondary.reader_endpoint : ""
}

output "secondary_db_cluster_id" {
  description = "The ID of the secondary RDS cluster"
  value       = var.setup_globaldb ? aws_rds_cluster.secondary.id : ""
}

output "secondary_db_instance_identifiers" {
  description = "The identifiers of the secondary RDS cluster instances"
  value       = var.setup_globaldb ? [for instance in aws_rds_cluster_instance.secondary : instance.id] : []
}

output "secondary_db_instance_endpoints" {
  description = "The endpoints of the secondary RDS cluster instances"
  value       = var.setup_globaldb ? [for instance in aws_rds_cluster_instance.secondary : instance.endpoint] : []
}

# IAM roles for RDS S3 import and export
output "rds_s3_export_role_arn" {
  description = "The ARN of the IAM role for RDS S3 export"
  value       = module.rds_s3_export_role.iam_role_arn
}

output "rds_s3_import_role_arn" {
  description = "The ARN of the IAM role for RDS S3 import"
  value       = module.rds_s3_import_role.iam_role_arn
}