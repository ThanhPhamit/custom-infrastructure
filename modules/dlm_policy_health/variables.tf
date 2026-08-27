# =============================================================================
# dlm_policy_health -- notice when EBS snapshot automation stops working.
#
# Data Lifecycle Manager publishes NO CloudWatch metrics (verified 2026-08-27: the AWS/DLM namespace
# does not exist in an account running an ENABLED policy), so there is nothing to alarm on. The only
# signal is EventBridge, which is why this module is a rule rather than an alarm.
#
# What it can and cannot see, stated plainly: it catches a policy that ERRORS or is DISABLED, and a
# snapshot that fails. It does NOT catch a policy that stays ENABLED and quietly produces nothing,
# because AWS emits no event for the absence of work. Detecting that needs a periodic check of the
# newest snapshot's age -- out of scope here, and worth knowing you do not have.
# =============================================================================

variable "app_name" {
  description = "Naming prefix for the rule."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "policy_ids" {
  description = "DLM lifecycle policy IDs to watch. Empty list = watch every policy in the account."
  type        = list(string)
  default     = []
}

variable "sns_topic_arn" {
  description = "SNS topic the rule publishes to. Its topic policy must allow events.amazonaws.com to publish -- a new topic's DEFAULT policy does not, and attaching one that omits cloudwatch.amazonaws.com silently breaks every alarm already using the topic."
  type        = string
}

variable "watch_snapshot_failures" {
  description = "Also match EBS snapshot notifications with result 'failed'. These are account-wide (aws.ec2), not DLM-scoped, so they include failures from snapshots nobody automated."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the rule."
  type        = map(string)
  default     = {}
}

variable "watch_api_changes" {
  description = <<-EOT
    Also match the CloudTrail API calls that change a DLM policy (UpdateLifecyclePolicy,
    DeleteLifecyclePolicy).

    This is the rule that actually earns its keep. Measured 2026-08-27: disabling a live DLM policy
    produced NO "DLM Policy State Change" event -- DLM emits that only when it moves a policy to
    ERROR itself. So without this, a human switching backups off is completely silent.

    Requires a CloudTrail trail logging management events in the region, otherwise the API-call
    events never reach the default event bus.
  EOT
  type        = bool
  default     = true
}
