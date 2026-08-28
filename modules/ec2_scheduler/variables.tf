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

variable "additional_start_expressions" {
  description = <<-EOT
    Extra cron expressions that fire the SAME start action a few minutes after start_expression.
    Retries, in other words -- and they are free of risk because StartInstances on an instance that
    is already running returns running/running with no error (measured 2026-08-27), so a retry that
    was not needed does nothing at all.

    Why this exists: a StartInstances call can return success while EC2 then fails the launch
    internally (StateTransitionReason "Server.InternalError"), leaving the instance stopped. The API
    reported success, so nothing retries it, no DLQ message is produced, and the host is simply
    absent until a human notices. Measured on a live single-instance stack: the 08:00 scheduled start failed
    that way on two consecutive weekdays while every start issued at another time of day succeeded,
    which is a strong hint that the exact hour boundary is the problem -- but AWS does not expose the
    reason, so the fix must work without knowing it.

    Two retries a few minutes apart turn a nine-hour outage into a four-minute one, unattended.

    Do NOT copy this idea to rds_scheduler. rds:StartDBInstance on an already-available instance
    returns InvalidDBInstanceState -- an error, not a no-op -- so an unnecessary RDS retry exhausts
    its retry_policy and lands in the dead-letter queue, turning every ordinary morning into a false
    page. Both behaviours measured 2026-08-27; the reasoning is written out in that module.
  EOT
  type        = list(string)
  default     = []
}

variable "volume_kms_key_arns" {
  description = <<-EOT
    Customer-managed KMS key ARNs encrypting the instances' EBS volumes. REQUIRED whenever the root
    or data volumes use a CMK; leave empty only for unencrypted volumes or the AWS-managed aws/ebs
    key, whose own key policy grants access through the service.

    Miss this and the schedule fails in the most expensive way available. Stopping an instance needs
    no key, so the evening stop works. Starting one does: EC2 must obtain a grant on the CMK as the
    CALLER, and a CMK whose key policy is the usual "kms:* to the account root" delegates that
    decision entirely to the caller's IAM policy. This role's policy grants EC2 and SQS actions only,
    so the start is accepted -- StartInstances returns pending with no error -- and EC2 then fails
    the launch internally, leaving the instance stopped with StateTransitionReason
    "Server.InternalError". No error code names KMS anywhere in that chain.

    Measured 2026-08-28 on a live stack after three days of it: every scheduler-initiated start
    failed, every start issued by an administrator (whose IAM carries kms:*) succeeded, and
    simulate-principal-policy returned implicitDeny for CreateGrant, Decrypt, DescribeKey and
    GenerateDataKeyWithoutPlaintext against the volumes' CMK.

    rds_scheduler needs no equivalent: RDS starts an encrypted instance through its own service
    access, and those schedules kept working throughout.
  EOT
  type        = list(string)
  default     = []
}
