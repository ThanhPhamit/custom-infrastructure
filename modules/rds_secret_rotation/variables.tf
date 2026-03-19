variable "app_name" {
  type        = string
  description = "Application name prefix for resource naming"
}

variable "region" {
  type        = string
  description = "AWS region"

  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "region must not be empty"
  }
}

variable "secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN for RDS credentials"
}

variable "db_port" {
  type        = number
  description = "RDS endpoint port"
  default     = 5432
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for rotation lambda networking"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used by rotation lambda"

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet"
  }
}

variable "rds_security_group_id" {
  type        = string
  description = "Security group ID attached to RDS"
}

variable "rotation_interval_days" {
  type        = number
  description = "Days between automatic password rotations"
  default     = 30

  validation {
    condition     = var.rotation_interval_days >= 1 && var.rotation_interval_days <= 1000
    error_message = "rotation_interval_days must be between 1 and 1000"
  }
}

variable "rotation_schedule_expression" {
  type        = string
  description = "Optional Secrets Manager schedule expression (cron/rate). When set, it is used instead of rotation_interval_days"
  default     = null

  validation {
    condition     = var.rotation_schedule_expression == null || can(regex("^(cron|rate)\\(.*\\)$", trimspace(var.rotation_schedule_expression)))
    error_message = "rotation_schedule_expression must be null or a valid schedule expression like cron(...) or rate(...)"
  }
}

variable "rotate_immediately" {
  type        = bool
  description = "Whether Secrets Manager should immediately rotate when rotation config is updated"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
