# =============================================================================
# alarm_office_hours_gate -- arm a set of CloudWatch alarms only during the hours the resource they
# watch is scheduled to be running, using EventBridge Scheduler universal targets. No Lambda.
#
# The problem it solves: an alarm whose metric DISAPPEARS when the resource is stopped has to pick a
# treat_missing_data policy, and both choices are wrong on a scheduled resource. "notBreaching" is
# silent on a scheduled stop and equally silent when the resource fails to come back. "breaching"
# catches the failed start but pages every single night. Gating the alarm's ACTIONS by time lets it
# keep "breaching" and stay quiet while the resource is legitimately off.
# =============================================================================

variable "app_name" {
  description = "Naming prefix for the schedules + IAM role (e.g. prod-tyo-lg-autoflow)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "alarm_names" {
  description = "CloudWatch alarm names to gate. The IAM policy is scoped to exactly these alarms. Give them empty ok_actions: the morning reset is an ALARM -> OK transition and would otherwise notify daily."
  type        = list(string)

  validation {
    condition     = length(var.alarm_names) > 0
    error_message = "Provide at least one alarm name."
  }
}

variable "timezone" {
  description = "IANA timezone the cron expressions are evaluated in. Must match the start/stop schedule that governs the resource, or the gate opens and closes against the wrong clock."
  type        = string
  default     = "Asia/Tokyo"
}

variable "disarm_expression" {
  description = "Cron that DISABLES the alarm actions. Must fire BEFORE the resource stops -- disarming after the stop leaves a window where the scheduled stop itself pages."
  type        = string
  default     = "cron(55 19 ? * MON-FRI *)"
}

variable "arm_expression" {
  description = <<-EOT
    Cron that ENABLES the alarm actions. Must fire BEFORE reset_expression, not after.

    Enabling actions is not itself a state transition, so arming an alarm that is already in ALARM
    sends nothing. That is the whole reason the reset exists, and it is why the order matters: arm
    first (silent), then reset to OK (silent, because ok_actions is empty), and let the next
    evaluation decide. If the resource is up the alarm stays OK; if it is not, the alarm transitions
    OK -> ALARM with actions live and the notification goes out.

    Reversing these two produces a gate that looks correct in the console and never fires.
  EOT
  type        = string
  default     = "cron(5 8 ? * MON-FRI *)"
}

variable "reset_expression" {
  description = "Cron that sets each alarm to OK so the next evaluation can produce a real transition. Must fire AFTER arm_expression, and late enough after the resource's start for a healthy resource to be publishing metrics again."
  type        = string
  default     = "cron(10 8 ? * MON-FRI *)"
}

variable "reset_state_reason" {
  description = "StateReason recorded on the morning reset. Shows up in the alarm history, so make it say why a human-looking state change appears every working day."
  type        = string
  default     = "Office-hours gate: cleared so the next evaluation reports the real state."
}

variable "enabled" {
  description = "Enable the gate schedules. false = all three created but DISABLED, which leaves the alarms permanently armed -- correct when the resource stops running on a schedule."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key encrypting the schedule payload at rest. null = the AWS-owned key. The payload is an alarm name, not a secret."
  type        = string
  default     = null
}

variable "dead_letter_arn" {
  description = "SQS queue ARN for invocations that exhaust their retries. Strongly recommended: a failed ARM is a silently disarmed alarm, which is the exact failure this module exists to prevent, and the DLQ is the only place it shows up."
  type        = string
  default     = null
}

variable "retry_maximum_attempts" {
  description = "Retry attempts for a failed invocation. AWS defaults to 185; 10 is enough for a gate and keeps a failure visible in the DLQ the same day."
  type        = number
  default     = 10

  validation {
    condition     = var.retry_maximum_attempts >= 0 && var.retry_maximum_attempts <= 185
    error_message = "retry_maximum_attempts must be between 0 and 185."
  }
}

variable "retry_maximum_event_age_seconds" {
  description = "How long a failed invocation stays retryable. 3600 keeps every retry inside the window it was meant for."
  type        = number
  default     = 3600

  validation {
    condition     = var.retry_maximum_event_age_seconds >= 60 && var.retry_maximum_event_age_seconds <= 86400
    error_message = "retry_maximum_event_age_seconds must be between 60 and 86400."
  }
}

variable "tags" {
  description = "Tags applied to the IAM role (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}

variable "alarm_names_no_reset" {
  description = <<-EOT
    Alarms to arm/disarm on the same schedule as alarm_names, but WITHOUT a morning reset.

    Use it for threshold alarms on a scheduled resource -- CPU, memory, disk. They run
    treat_missing_data = "missing", so they sit in INSUFFICIENT_DATA overnight (silent, because
    insufficient_data_actions is empty) and transition back to OK on their own the moment the
    resource publishes again. If they carry ok_actions, that transition posts a meaningless "OK"
    every single working morning -- on a 22-working-day month, one alarm becomes 22 messages that
    mean nothing, and a channel that trains people to skim is worse than no channel.

    Disarming them across the off-window makes the boot-time recovery silent while leaving a REAL
    daytime recovery notification intact. They need no reset: unlike a "breaching" absent alarm,
    nothing latches them in ALARM overnight, so there is no stuck state to clear.
  EOT
  type        = list(string)
  default     = []
}
