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

  validation {
    condition     = var.db_subnet_group_name != null || length(var.private_subnet_ids) > 0
    error_message = "Either db_subnet_group_name must be provided, or private_subnet_ids must contain at least one subnet"
  }
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

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Enable automatic minor version upgrades during maintenance window"
  default     = true
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
  description = "Number of days to retain automated backups"
  default     = 7
}

variable "backup_window" {
  type        = string
  description = "Preferred backup window (UTC)"
  default     = "20:57-21:27"
}

variable "maintenance_window" {
  type        = string
  description = "Preferred maintenance window (format: ddd:hh24:mi-ddd:hh24:mi UTC). If null, AWS selects a window."
  default     = null
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

  validation {
    condition     = var.skip_final_snapshot || (var.final_snapshot_identifier != null && length(trimspace(var.final_snapshot_identifier)) > 0)
    error_message = "final_snapshot_identifier is required when skip_final_snapshot is false"
  }
}

#--------------------------------------------------------------
# Variables - Security
#--------------------------------------------------------------
variable "restricted_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs allowed to access the RDS instance"
  default     = []
}

variable "egress_rules" {
  description = "Egress rules for the RDS security group. Default [] = no egress (deny-all), which suits most databases. Add rules only if the DB must initiate outbound connections (e.g. S3 integration via VPC endpoints)."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string, "")
  }))
  default = []
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

variable "cloudwatch_log_retention_in_days" {
  type        = number
  description = "Number of days to retain exported RDS CloudWatch logs"
  default     = 30

  validation {
    condition     = var.cloudwatch_log_retention_in_days >= 1 && var.cloudwatch_log_retention_in_days <= 3653
    error_message = "cloudwatch_log_retention_in_days must be between 1 and 3653 days."
  }
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

  validation {
    condition     = var.create_parameter_group || (var.parameter_group_name != null && length(trimspace(var.parameter_group_name)) > 0)
    error_message = "parameter_group_name is required when create_parameter_group is false"
  }
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

variable "enable_slow_query_log" {
  type        = bool
  description = "Enable PostgreSQL slow query logging via log_min_duration_statement"
  default     = true
}

variable "slow_query_log_min_duration_ms" {
  type        = number
  description = "PostgreSQL slow query threshold in milliseconds for log_min_duration_statement"
  default     = 500

  validation {
    condition     = var.slow_query_log_min_duration_ms >= 0 && var.slow_query_log_min_duration_ms <= 600000
    error_message = "slow_query_log_min_duration_ms must be between 0 and 600000 milliseconds."
  }
}

variable "enable_log_lock_waits" {
  type        = bool
  description = "Enable PostgreSQL lock wait logging"
  default     = true
}

variable "enable_track_io_timing" {
  type        = bool
  description = "Enable PostgreSQL track_io_timing for query performance analysis"
  default     = true
}

variable "idle_in_transaction_session_timeout_ms" {
  type        = number
  description = "Terminate sessions idle in transaction longer than this threshold (ms). Prevents lock pile-ups from crashed clients. 0 to disable."
  default     = 30000

  validation {
    condition     = var.idle_in_transaction_session_timeout_ms >= 0
    error_message = "idle_in_transaction_session_timeout_ms must be 0 (disabled) or a positive number of milliseconds."
  }
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
