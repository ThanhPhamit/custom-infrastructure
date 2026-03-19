variable "app_name" {
  type        = string
  description = "Application name prefix used for resource naming"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "rds_password_secret_arn" {
  type        = string
  description = "RDS password secret ARN that emits Rotation Succeeded events"
}

variable "rollout_mode" {
  type        = string
  description = "Rollout mode after rotation: codedeploy_s3_appspec or ecs_force_new_deployment"
  default     = "codedeploy_s3_appspec"

  validation {
    condition     = contains(["codedeploy_s3_appspec", "ecs_force_new_deployment"], var.rollout_mode)
    error_message = "rollout_mode must be one of: codedeploy_s3_appspec, ecs_force_new_deployment"
  }

  validation {
    condition     = var.rollout_mode != "ecs_force_new_deployment" || length(var.ecs_targets) > 0
    error_message = "ecs_targets must not be empty when rollout_mode=ecs_force_new_deployment"
  }

  validation {
    condition     = var.rollout_mode != "codedeploy_s3_appspec" || length(var.codedeploy_targets) > 0
    error_message = "codedeploy_targets must not be empty when rollout_mode=codedeploy_s3_appspec"
  }
}

variable "ecs_targets" {
  type = list(object({
    cluster_name = string
    service_name = string
  }))
  description = "ECS services to rollout when rollout_mode is ecs_force_new_deployment"
  default     = []
}

variable "codedeploy_targets" {
  type = list(object({
    application_name      = string
    deployment_group_name = string
    s3_bucket             = string
    s3_key                = string
    fallback_s3_key       = optional(string, "appspec.yaml")
    bundle_type           = optional(string, "yaml")
  }))
  description = "CodeDeploy targets and revision location used when rollout_mode is codedeploy_s3_appspec"
  default     = []

  validation {
    condition = alltrue([
      for target in var.codedeploy_targets : contains(["yaml", "json", "zip", "tar", "tgz"], lower(try(target.bundle_type, "yaml")))
    ])
    error_message = "Each codedeploy target bundle_type must be one of: yaml, json, zip, tar, tgz"
  }
}

variable "delay_seconds" {
  type        = number
  description = "Delay before triggering rollout to allow secret propagation"
  default     = 30

  validation {
    condition     = var.delay_seconds >= 30 && var.delay_seconds <= 60
    error_message = "delay_seconds must be between 30 and 60 seconds"
  }
}

variable "sync_runtime_secret_arn" {
  type        = string
  description = "Optional consolidated runtime secret ARN to sync rotated password into"
  default     = null
}

variable "sync_runtime_secret_key" {
  type        = string
  description = "JSON key to update in consolidated runtime secret"
  default     = "postgres_password"

  validation {
    condition     = length(trimspace(var.sync_runtime_secret_key)) > 0
    error_message = "sync_runtime_secret_key must not be empty"
  }
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda timeout in seconds"
  default     = 180
}

variable "lambda_memory_size" {
  type        = number
  description = "Lambda memory size in MB"
  default     = 256
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
