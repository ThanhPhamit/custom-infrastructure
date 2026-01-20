variable "region" {
  type = string
}
variable "profile" {
  type = string
}
variable "environment" {
  type        = string
  description = "The environment for the application (e.g., stg, prod)"
}
variable "app_name" {
  description = "The name of the application"
}

# Namecard Extracting Module
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

# Define the variable for subnet IDs
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

# OIDC identity provider for GitHub Actions
variable "thumbprint_list" {
  description = "A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)."
  type        = list(string)
}


# SLACK Module
variable "slack_workspace_id" {
  type    = string
  default = "T03ARELF1" #ワークスペースIDを入力
}

variable "slack_notice_channel_id" {
  type    = string
  default = "C08MRFN2T5L" #チャネルIDを入力
}

variable "slack_alert_channel_id" {
  type    = string
  default = "C08N2NV74LT" #チャネルIDを入力
}


# Remark AI Tool - Scheduled ECS Task
variable "remark_ai_tool_enabled" {
  description = "Enable the Remark AI Tool scheduled task"
  type        = bool
  default     = true
}

variable "remark_ai_tool_schedule" {
  description = "Schedule expression for Remark AI Tool (rate or cron)"
  type        = string
  default     = "rate(1 hour)"
}

variable "remark_ai_tool_task_cpu" {
  description = "CPU units for Remark AI Tool task"
  type        = string
  default     = "256"
}

variable "remark_ai_tool_task_memory" {
  description = "Memory for Remark AI Tool task in MB"
  type        = string
  default     = "512"
}

variable "remark_ai_tool_environment_vars" {
  description = "Environment variables for Remark AI Tool container"
  type        = map(string)
  default     = {}
}

variable "remark_ai_tool_db_password" {
  description = "Database password for Remark AI Tool (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}
