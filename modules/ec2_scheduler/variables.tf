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

variable "kms_key_arn" {
  description = "Customer-managed KMS key encrypting the schedule payload at rest. null = the AWS-owned key. The payload here is an instance identifier, not a secret, so a CMK is usually unnecessary -- but the choice belongs to the caller, and a compliance baseline that requires CMK everywhere can set it. Note the key policy must allow scheduler.amazonaws.com."
  type        = string
  default     = null
}

variable "retry_maximum_attempts" {
  description = "Retry attempts for a failed invocation. AWS defaults to 185, which pairs with a 24-hour event age -- wrong for a STOP schedule: a 19:00 stop that keeps retrying can succeed at 10:00 the next working day and take production down mid-morning. Giving up beats succeeding at the wrong hour."
  type        = number
  default     = 10

  validation {
    condition     = var.retry_maximum_attempts >= 0 && var.retry_maximum_attempts <= 185
    error_message = "maximum_retry_attempts must be between 0 and 185."
  }
}

variable "retry_maximum_event_age_seconds" {
  description = "How long a failed invocation stays retryable. Default 3600 (1 hour) keeps every retry inside the window the schedule was meant for; AWS defaults to 86400, which spills into the next day."
  type        = number
  default     = 3600

  validation {
    condition     = var.retry_maximum_event_age_seconds >= 60 && var.retry_maximum_event_age_seconds <= 86400
    error_message = "maximum_event_age_in_seconds must be between 60 and 86400."
  }
}

variable "dead_letter_arn" {
  description = "SQS queue ARN receiving invocations that fail every retry. null = NO dead letter, which means a permanently failed start/stop is SILENT: the instance simply stays as it was and nobody is told until the bill or a user complains. The module does not create the queue -- owning a queue is a separate responsibility, and one queue usually serves several schedulers."
  type        = string
  default     = null
}
