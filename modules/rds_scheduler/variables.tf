variable "app_name" {
  description = "Naming prefix for the schedules + IAM role (e.g. prod-tyo-myapp)."
  type        = string

  validation {
    condition     = length(var.app_name) > 0
    error_message = "app_name must not be empty."
  }
}

variable "db_instance_arns" {
  description = "RDS DB instance ARNs to start/stop. Identifiers are derived from these for the schedule input; the IAM policy is scoped to exactly these ARNs. Mirrors ec2_scheduler's instance_arns so the two modules compose the same way."
  type        = list(string)

  validation {
    condition     = length(var.db_instance_arns) > 0
    error_message = "Provide at least one DB instance ARN."
  }

  validation {
    condition     = alltrue([for a in var.db_instance_arns : can(regex("^arn:[a-z-]+:rds:[a-z0-9-]+:[0-9]{12}:db:", a))])
    error_message = "Each entry must be a DB INSTANCE arn (arn:<partition>:rds:<region>:<account>:db:<identifier>). Cluster ARNs (:cluster:) are not supported — Aurora is started/stopped as a cluster, which is a different API."
  }
}

variable "start_expression" {
  description = "EventBridge Scheduler cron for starting. Format: cron(min hour dom month dow year)."
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "stop_expression" {
  description = "EventBridge Scheduler cron for stopping."
  type        = string
  default     = "cron(0 20 ? * MON-FRI *)"
}

variable "timezone" {
  description = "IANA timezone the cron expressions are evaluated in (e.g. Asia/Tokyo). Scheduler handles DST for zones that observe it."
  type        = string
  default     = "Asia/Tokyo"
}

variable "enabled" {
  description = "Enable the schedules. false = both schedules created but DISABLED (instances stay as they are). Flip this rather than destroying the module, so the schedule stays reviewable in code."
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

# =============================================================================
# DELIBERATELY ABSENT: additional_start_expressions
#
# ec2_scheduler has that knob -- extra crons that re-issue the start a few minutes later, to survive
# a StartInstances call that AWS accepts and then fails internally. Do NOT mirror it here by analogy.
#
# The two APIs behave differently, measured 2026-08-27 against a live instance:
#
#   ec2:StartInstances      on an already-running instance  -> running/running, no error
#   rds:StartDBInstance     on an already-available instance -> InvalidDBInstanceState, ERROR
#
# So an EC2 retry that was not needed is a no-op, while an RDS retry that was not needed FAILS. With
# a retry_policy and a dead_letter_arn attached, that failure exhausts its retries and lands in the
# DLQ -- so every ordinary morning would produce a dead-letter message and, if the queue is alarmed,
# a daily false page. The alerting would be lying on exactly the days nothing is wrong.
#
# If a scheduled RDS start ever does need retrying, it has to check the instance state first, which
# EventBridge Scheduler's universal targets cannot do. That is a Lambda or a Step Function, not a
# variable on this module.
# =============================================================================
