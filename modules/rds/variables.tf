#--------------------------------------------------------------
# Variables - Required
#--------------------------------------------------------------
variable "app_name" {
  type        = string
  description = "Application name used for resource naming"
}

variable "db_name" {
  type        = string
  description = "Database identifier name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where RDS will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the DB subnet group (required if db_subnet_group_name is not provided)"
  default     = []
}

variable "db_subnet_group_name" {
  type        = string
  description = "Name of an existing DB subnet group (from network module). If provided, private_subnet_ids will be ignored."
  default     = null
}

variable "availability_zone" {
  type        = string
  description = "Primary availability zone for the RDS instance"
}

#--------------------------------------------------------------
# Variables - Database Configuration
#--------------------------------------------------------------
variable "db_database" {
  type        = string
  description = "Name of the default database to create"
  default     = "main"
}

variable "db_username" {
  type        = string
  description = "Master username for the database"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  description = "Master password (if empty, will be auto-generated and stored in Secrets Manager)"
  default     = ""
  sensitive   = true
}

variable "db_port" {
  type        = number
  description = "Database port"
  default     = 5432
}

#--------------------------------------------------------------
# Variables - Engine Configuration
#--------------------------------------------------------------
variable "engine" {
  type        = string
  description = "Database engine type (postgres, mysql, mariadb)"
  default     = "postgres"
}

variable "engine_version" {
  type        = string
  description = "Database engine version"
  default     = "17.2"
}

variable "engine_family" {
  type        = string
  description = "Parameter group family (e.g., postgres17, mysql8.0)"
  default     = "postgres17"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

#--------------------------------------------------------------
# Variables - Storage Configuration
#--------------------------------------------------------------
variable "allocated_storage" {
  type        = number
  description = "Initial allocated storage in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage for autoscaling in GB (0 to disable)"
  default     = 100
}

variable "storage_type" {
  type        = string
  description = "Storage type (gp2, gp3, io1)"
  default     = "gp3"
}

variable "storage_encrypted" {
  type        = bool
  description = "Enable storage encryption"
  default     = true
}

#--------------------------------------------------------------
# Variables - High Availability & Replica
#--------------------------------------------------------------
variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment"
  default     = false
}

variable "create_replica" {
  type        = bool
  description = "Create a read replica"
  default     = false
}

variable "replica_availability_zone" {
  type        = string
  description = "Availability zone for the read replica"
  default     = null
}

variable "replica_instance_class" {
  type        = string
  description = "Instance class for replica (defaults to same as primary)"
  default     = null
}

#--------------------------------------------------------------
# Variables - Backup Configuration
#--------------------------------------------------------------
variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain backups"
  default     = 35
}

variable "backup_window" {
  type        = string
  description = "Preferred backup window (UTC)"
  default     = "20:57-21:27"
}

variable "delete_automated_backups" {
  type        = bool
  description = "Delete automated backups when instance is deleted"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on deletion"
  default     = false
}

variable "final_snapshot_identifier" {
  type        = string
  description = "Name for the final snapshot (required if skip_final_snapshot is false)"
  default     = null
}

#--------------------------------------------------------------
# Variables - Security
#--------------------------------------------------------------
variable "restricted_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs allowed to access the RDS instance"
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the RDS instance"
  default     = []
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}

#--------------------------------------------------------------
# Variables - Monitoring & Performance
#--------------------------------------------------------------
variable "monitoring_interval" {
  type        = number
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Valid values: 0, 1, 5, 10, 15, 30, 60"
  }
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights"
  default     = true
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Performance Insights retention period in days (7, 731 for paid)"
  default     = 7
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "List of log types to export to CloudWatch"
  default     = ["postgresql", "upgrade"]
}

#--------------------------------------------------------------
# Variables - Parameter Group
#--------------------------------------------------------------
variable "create_parameter_group" {
  type        = bool
  description = "Create a custom parameter group"
  default     = true
}

variable "parameter_group_name" {
  type        = string
  description = "Name of existing parameter group (if create_parameter_group is false)"
  default     = null
}

variable "custom_parameters" {
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "pending-reboot")
  }))
  description = "Custom parameters for the parameter group"
  default     = []
}

#--------------------------------------------------------------
# Variables - S3 Integration (PostgreSQL only)
#--------------------------------------------------------------
variable "enable_s3_integration" {
  type        = bool
  description = "Enable S3 import/export integration (PostgreSQL only)"
  default     = false
}

variable "s3_bucket_arns" {
  type        = list(string)
  description = "List of S3 bucket ARNs for import/export (null for all buckets)"
  default     = null
}

#--------------------------------------------------------------
# Variables - Tags
#--------------------------------------------------------------
variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
