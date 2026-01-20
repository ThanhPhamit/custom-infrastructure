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

# EventBridge Configuration
variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., rate(1 hour), cron(0 12 * * ? *))"
  type        = string
}

variable "rule_name" {
  description = "Name of the EventBridge rule (optional, defaults to app_name-scheduled-rule)"
  type        = string
  default     = null
}

variable "rule_description" {
  description = "Description of the EventBridge rule"
  type        = string
  default     = "Scheduled task trigger"
}

variable "enable_rule" {
  description = "Enable the EventBridge rule"
  type        = bool
  default     = true
}

# Target Configuration
variable "target_type" {
  description = "Type of target (ecs or lambda)"
  type        = string
  validation {
    condition     = contains(["ecs", "lambda"], var.target_type)
    error_message = "Target type must be 'ecs' or 'lambda'."
  }
}

# ECS Target Configuration (when target_type = "ecs")
variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster (required when target_type is ecs)"
  type        = string
  default     = null
}

variable "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition (required when target_type is ecs)"
  type        = string
  default     = null
}

variable "ecs_task_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for the ECS task (required when target_type is ecs)"
  type        = list(string)
  default     = []
}

variable "ecs_security_group_ids" {
  description = "Security group IDs for the ECS task"
  type        = list(string)
  default     = []
}

variable "ecs_assign_public_ip" {
  description = "Assign public IP to ECS task"
  type        = bool
  default     = false
}

variable "ecs_launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
}

variable "ecs_platform_version" {
  description = "ECS platform version"
  type        = string
  default     = "LATEST"
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role (optional)"
  type        = string
  default     = null
}

# Lambda Target Configuration (when target_type = "lambda")
variable "lambda_function_arn" {
  description = "ARN of the Lambda function (required when target_type is lambda)"
  type        = string
  default     = null
}

variable "lambda_input" {
  description = "JSON input to pass to the Lambda function"
  type        = string
  default     = null
}

# Common Target Configuration
variable "target_input" {
  description = "JSON input to pass to the target (for custom input)"
  type        = string
  default     = null
}

variable "target_input_transformer" {
  description = "Input transformer configuration"
  type = object({
    input_paths    = map(string)
    input_template = string
  })
  default = null
}
