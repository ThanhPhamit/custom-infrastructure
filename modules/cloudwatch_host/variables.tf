variable "app_name" {
  description = "Naming prefix (e.g. myapp-prod)."
  type        = string
}

variable "instance_id" {
  description = "EC2 instance ID the alarms watch (sole metric dimension)."
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm + OK actions (e.g. the chatbot_slack topic)."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group name for the app/host (e.g. /myapp/prod/app)."
  type        = string
}

variable "log_retention_in_days" {
  description = "Log retention in days."
  type        = number
  default     = 30
}

variable "log_kms_key_id" {
  description = "Optional CMK ARN to encrypt the log group. null = default CloudWatch Logs encryption. (Using a CMK requires the key policy to allow the logs service — left null by default to keep the CMK policy simple.)"
  type        = string
  default     = null
}

variable "cpu_threshold" {
  description = "CPUUtilization % that trips the CPU alarm."
  type        = number
  default     = 85
}

variable "memory_threshold" {
  description = "CWAgent mem_used_percent that trips the memory alarm (RAM pressure signal)."
  type        = number
  default     = 85
}

variable "disk_threshold" {
  description = "CWAgent disk_used_percent (root fs) that trips the disk alarm."
  type        = number
  default     = 85
}

variable "create_memory_alarm" {
  description = "Create the memory alarm. Requires the CloudWatch agent to emit mem_used_percent aggregated to the InstanceId dimension."
  type        = bool
  default     = true
}

variable "create_disk_alarm" {
  description = "Create the disk alarm. Requires the CloudWatch agent to emit disk_used_percent aggregated to the InstanceId dimension."
  type        = bool
  default     = true
}

variable "cwagent_namespace" {
  description = "CloudWatch namespace the agent publishes to."
  type        = string
  default     = "CWAgent"
}

variable "period" {
  description = "Alarm evaluation period in seconds."
  type        = number
  default     = 300
}

variable "evaluation_periods" {
  description = "Number of periods that must breach before ALARM."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags applied to all resources (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}

variable "status_check_treat_missing_data" {
  description = "How the StatusCheckFailed alarm treats missing data. Default \"breaching\" suits an always-on host (a stopped instance publishes nothing, so absence IS the failure signal). Use \"notBreaching\" when the instance runs on a start/stop schedule, or every scheduled stop pages -- a running-but-broken instance still publishes 1 and still alarms."
  type        = string
  default     = "breaching"

  validation {
    condition     = contains(["breaching", "notBreaching", "ignore", "missing"], var.status_check_treat_missing_data)
    error_message = "Must be one of: breaching, notBreaching, ignore, missing."
  }
}

variable "create_host_absent_alarm" {
  description = <<-EOT
    Create a SECOND alarm on the same StatusCheckFailed metric, but with treat_missing_data =
    "breaching", to answer the question the status-check alarm deliberately cannot: "the host is
    supposed to be running right now and it is not there at all".

    Only useful on a host with a start/stop schedule, and only alongside an office-hours gate that
    disarms this alarm's actions while the host is meant to be off (see the alarm_office_hours_gate module)
    -- ungated it pages on every scheduled stop.

    Its ok_actions are deliberately EMPTY. The gate resets it to OK each morning before re-arming,
    and an OK notification on that reset would be a daily message that means nothing.
  EOT
  type        = bool
  default     = false
}
