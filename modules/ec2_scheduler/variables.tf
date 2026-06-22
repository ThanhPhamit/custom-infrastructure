# =============================================================================
# ec2_scheduler — start/stop a set of EC2 instances on a cron schedule using
# EventBridge Scheduler universal targets (aws-sdk:ec2:startInstances /
# stopInstances). No Lambda. Cheapest way to power staging down off-hours; EC2
# bills no compute while stopped (EBS + EIP still bill).
# =============================================================================

variable "app_name" {
  description = "Naming prefix for the schedules + IAM role (e.g. tokyo-staging-hinerism)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "instance_arns" {
  description = "EC2 instance ARNs to start/stop. Instance IDs are derived from these for the schedule input; the IAM policy is scoped to exactly these ARNs."
  type        = list(string)

  validation {
    condition     = length(var.instance_arns) > 0
    error_message = "Provide at least one instance ARN."
  }
}

variable "start_expression" {
  description = "EventBridge Scheduler cron for starting (default: 08:00 Mon–Fri). Format: cron(min hour dom month dow year)."
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "stop_expression" {
  description = "EventBridge Scheduler cron for stopping (default: 20:00 Mon–Fri)."
  type        = string
  default     = "cron(0 20 ? * MON-FRI *)"
}

variable "timezone" {
  description = "IANA timezone the cron expressions are evaluated in (e.g. Asia/Tokyo)."
  type        = string
  default     = "Asia/Tokyo"
}

variable "enabled" {
  description = "Enable the schedules. false = both schedules created but DISABLED (instances stay on)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the IAM role (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}
