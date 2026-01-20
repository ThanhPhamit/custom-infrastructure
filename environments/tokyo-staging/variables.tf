variable "region" {
  type = string
}
variable "profile" {
  type = string
}
variable "app_name" {}

# Network module
variable "azs_name" {}
variable "vpc_cidr" {}
variable "public_subnet_ciders" {}
variable "private_subnet_ciders" {}

# RDS cluster module
variable "sec_region" {
  description = "The name of the secondary AWS region you wish to deploy into"
  type        = string
}
variable "identifier" {
  description = "Cluster identifier"
  type        = string
  default     = "aurora"
}
variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "aurora"
}
variable "manage_master_user_password" {
  description = "Manage master user password using AWS Secrets Manager"
  type        = bool
  default     = false
}

variable "engine" {
  description = "Aurora database engine type: aurora, aurora-mysql, aurora-postgresql"
  type        = string
  default     = "aurora-postgresql"
  #default     = "aurora-mysql"
}
variable "engine_version_pg" {
  description = "Aurora PostgreSQL database engine version."
  type        = string
}

variable "engine_version_mysql" {
  description = "Aurora MySQL database engine version."
  type        = string
}

variable "db_instance_class" {
  type        = string
  description = "Aurora DB Instance type. Specify db.serverless to create Aurora Serverless v2 instances."
}
variable "setup_globaldb" {
  description = "Setup Aurora Global Database with 1 Primary and 1 X-region Secondary cluster"
  type        = bool
  default     = false
}

variable "setup_as_secondary" {
  description = "Setup aws_rds_cluster.primary Terraform resource as Secondary Aurora cluster after an unplanned Aurora Global DB failover"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds"
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Valid values for var: monitoring_interval are (0, 1, 5, 10, 15, 30, 60)."
  }
}

variable "snapshot_identifier" {
  description = "id of snapshot to restore. If you do not want to restore a db, leave the default empty string."
  type        = string
  default     = ""
}

variable "storage_encrypted" {
  description = "Specifies whether the underlying Aurora storage layer should be encrypted"
  type        = bool
  default     = false
}

variable "storage_type" {
  description = "Specifies Aurora storage type: Aurora Standard vs. Aurora I/O-Optimized"
  type        = string
  default     = ""
}

variable "primary_instance_count" {
  description = "instance count for primary Aurora cluster"
  type        = number
  default     = 2
}

variable "secondary_instance_count" {
  description = "instance count for secondary Aurora cluster"
  type        = number
  default     = 1
}