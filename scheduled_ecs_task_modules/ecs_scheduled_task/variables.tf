# Required variables
variable "app_name" {
  description = "Application name for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ECS Cluster Configuration
variable "cluster_name" {
  description = "Name of the ECS cluster (if not provided, will use app_name)"
  type        = string
  default     = null
}

# Task Definition Configuration
variable "ecr_image_uri" {
  description = "ECR image URI for the container"
  type        = string
}

variable "container_name" {
  description = "Name of the container in the task definition"
  type        = string
  default     = "app"
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.task_cpu)
    error_message = "Task CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "task_memory" {
  description = "Memory for the task in MB (512, 1024, 2048, 4096, 8192, 16384, 30720)"
  type        = string
  default     = "512"
}

variable "container_environment" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "Secrets for the container from AWS Secrets Manager or Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "container_command" {
  description = "Command to run in the container"
  type        = list(string)
  default     = null
}

variable "container_entrypoint" {
  description = "Entrypoint for the container"
  type        = list(string)
  default     = null
}

variable "working_directory" {
  description = "Working directory for the container"
  type        = string
  default     = null
}

# CloudWatch Logs Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period"
  }
}

variable "log_group_name" {
  description = "CloudWatch log group name (if not provided, will use /ecs/app_name)"
  type        = string
  default     = null
}

# IAM Configuration
variable "task_role_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the task role"
  type        = list(string)
  default     = []
}

variable "task_execution_role_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the task execution role"
  type        = list(string)
  default     = []
}

variable "task_role_inline_policies" {
  description = "Inline policies to attach to the task role"
  type = map(object({
    policy = string
  }))
  default = {}
}

# Network Configuration (for reference in outputs)
variable "vpc_id" {
  description = "VPC ID where the task will run (for security group creation if needed)"
  type        = string
  default     = null
}
