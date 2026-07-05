################################################################################
# General
################################################################################

variable "app_name" {
  description = "Application/name prefix applied to every resource name and the Name tag (e.g. \"s2s-vpn-lab\")."
  type        = string

  validation {
    condition     = length(trimspace(var.app_name)) > 0
    error_message = "app_name must be a non-empty string."
  }
}

variable "tags" {
  description = "Additional tags merged onto every taggable resource created by this module."
  type        = map(string)
  default     = {}
}

################################################################################
# Networking
################################################################################

variable "vpc_id" {
  description = "ID of the VPC in which the Aurora cluster security group is created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g. vpc-0123456789abcdef0)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs (>=2, spread across AZs) used to build the DB subnet group for the Aurora cluster."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least 2 subnet IDs across distinct Availability Zones."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the Aurora cluster on TCP 5432 (e.g. on-prem ranges reachable over the S2S VPN)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "allowed_cidr_blocks must contain at least one CIDR block."
  }
}

################################################################################
# Engine / instances
################################################################################

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (must be available in the target region; the operator confirms availability)."
  type        = string
  default     = "16.6"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)*$", var.engine_version))
    error_message = "engine_version must be a dotted numeric version string (e.g. \"16.6\")."
  }
}

variable "instance_class" {
  description = "Instance class for each Aurora cluster instance (e.g. \"db.t4g.medium\")."
  type        = string
  default     = "db.t4g.medium"

  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "instance_class must be a valid RDS instance class beginning with \"db.\"."
  }
}

variable "instance_count" {
  description = "Number of Aurora cluster instances to provision (writer + optional readers)."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

################################################################################
# Database identity
################################################################################

variable "master_username" {
  description = "Master username for the Aurora cluster. The password is managed by RDS (manage_master_user_password)."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = length(trimspace(var.master_username)) > 0
    error_message = "master_username must be a non-empty string."
  }
}

variable "database_name" {
  description = "Name of an initial database to create in the cluster. null means no initial database is created."
  type        = string
  default     = null
}

################################################################################
# Backups / lifecycle
################################################################################

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (1-35)."
  type        = number
  default     = 1

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 1 and 35 days."
  }
}

variable "preferred_backup_window" {
  description = "Daily time range (UTC) during which automated backups are taken, in \"hh:mm-hh:mm\" format."
  type        = string
  default     = "16:00-17:00"

  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$", var.preferred_backup_window))
    error_message = "preferred_backup_window must be in \"hh:mm-hh:mm\" 24-hour UTC format (e.g. \"16:00-17:00\")."
  }
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled on the cluster. Keep false in throwaway labs so terraform destroy works."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the cluster is destroyed. true is teardown-friendly."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately rather than during the next maintenance window."
  type        = bool
  default     = true
}

################################################################################
# Encryption / auth
################################################################################

variable "storage_encrypted" {
  description = "Whether storage encryption at rest is enabled for the cluster."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN/ID used for storage encryption. null uses the AWS-managed aws/rds key."
  type        = string
  default     = null
}

variable "iam_database_authentication_enabled" {
  description = "Whether IAM database authentication is enabled for the cluster."
  type        = bool
  default     = true
}

variable "force_ssl" {
  description = "Whether to set rds.force_ssl=1 on the custom cluster parameter group, forcing TLS for all connections."
  type        = bool
  default     = true
}

variable "ca_cert_identifier" {
  description = "RDS server CA certificate identifier pinned on each instance. Pinning keeps the server CA deterministic/Terraform-tracked so sslmode=verify-full clients are not broken by an unattended CA rotation. null lets AWS choose the regional default."
  type        = string
  default     = "rds-ca-rsa2048-g1"
}

################################################################################
# Observability
################################################################################

variable "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled on each cluster instance."
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights data retention in days (7 = free tier; otherwise 31-month multiples up to 731)."
  type        = number
  default     = 7

  validation {
    condition     = var.performance_insights_retention_period == 7 || var.performance_insights_retention_period == 731 || (var.performance_insights_retention_period % 31 == 0 && var.performance_insights_retention_period >= 31)
    error_message = "performance_insights_retention_period must be 7, 731, or a multiple of 31 between 31 and 713."
  }
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring granularity in seconds (0 disables; valid values 0, 1, 5, 10, 15, 30, 60)."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types exported to CloudWatch Logs (for Aurora PostgreSQL: \"postgresql\")."
  type        = list(string)
  default     = ["postgresql"]
}

################################################################################
# Event subscription (optional)
################################################################################

variable "enable_event_subscription" {
  description = "Whether to create the RDS db-cluster event subscription. Kept separate from the topic ARN because the ARN is typically unknown at plan time and cannot drive count."
  type        = bool
  default     = false
}

variable "event_subscription_sns_topic_arn" {
  description = "SNS topic ARN that receives RDS db-cluster event notifications. Only used when enable_event_subscription is true."
  type        = string
  default     = null
}

################################################################################
# CloudWatch alarms (optional)
################################################################################

variable "enable_alarms" {
  description = "Whether to create a per-instance CPUUtilization CloudWatch alarm for the cluster instances."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified on ALARM transitions for the CPU alarms (only used when enable_alarms = true)."
  type        = list(string)
  default     = []
}

variable "alarm_cpu_threshold" {
  description = "CPUUtilization percentage threshold above which the per-instance CPU alarm fires."
  type        = number
  default     = 80

  validation {
    condition     = var.alarm_cpu_threshold > 0 && var.alarm_cpu_threshold <= 100
    error_message = "alarm_cpu_threshold must be between 1 and 100."
  }
}

variable "auto_minor_version_upgrade" {
  description = "Whether AWS may apply minor engine upgrades automatically. Default false so the pinned engine_version stays Terraform-authoritative (no silent drift); version bumps are made by changing engine_version."
  type        = bool
  default     = false
}
