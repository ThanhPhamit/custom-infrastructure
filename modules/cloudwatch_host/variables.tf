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
    disarms this alarm's actions while the host is meant to be off (see modules/alarm_office_hours_gate)
    -- ungated it pages on every scheduled stop.

    Its ok_actions are deliberately EMPTY. The gate resets it to OK each morning before re-arming,
    and an OK notification on that reset would be a daily message that means nothing.
  EOT
  type        = bool
  default     = false
}

variable "create_schedule_overrun_alarm" {
  description = <<-EOT
    Create an alarm that fires when the host ran for MORE minutes in a day than its schedule allows
    -- i.e. a stop that silently did not happen. Costs nothing to run and needs no office-hours gate,
    because it counts rather than samples: StatusCheckFailed publishes exactly one datapoint per
    minute while the instance lives, so the daily SampleCount IS the number of minutes it ran.

    A 13-hour weekday window is 780 datapoints; an instance that never stopped is 1440. The default
    threshold sits between them. Weekends and holidays produce no data at all, which is why
    treat_missing_data is notBreaching here: absence is the good case.
  EOT
  type        = bool
  default     = false
}

variable "schedule_overrun_max_minutes_per_day" {
  description = "Minutes per day above which the host is considered to have overrun its schedule. Set it comfortably above the real window (13 h = 780) and below 1440. The alarm evaluates a ROLLING 24-hour window, not a calendar day -- and any rolling 24 h contains at most one such run, because consecutive runs are separated by more off-hours than on-hours. So the number needs no adjusting for a non-UTC schedule, but do not reason about it as a calendar day (measured 2026-08-27: the alarm read 832 while a calendar-day query of the same metric read 776)."
  type        = number
  default     = 1000

  validation {
    condition     = var.schedule_overrun_max_minutes_per_day > 0 && var.schedule_overrun_max_minutes_per_day < 1440
    error_message = "schedule_overrun_max_minutes_per_day must be between 1 and 1439 (1440 = always on, which can never breach)."
  }
}

variable "disk_paths" {
  description = <<-EOT
    Filesystem paths to alarm on individually, e.g. ["/", "/data"]. One alarm per path, dimensioned
    {InstanceId, path}.

    Use this instead of create_disk_alarm whenever the agent reports more than one filesystem. The
    reason is a trap worth stating plainly: the CloudWatch agent rolls disk metrics up according to
    its aggregation_dimensions, and the InstanceId-only rollup that create_disk_alarm reads is an
    AVERAGE across every filesystem. A root filesystem at 95% next to a data volume at 5% averages to
    50% and never breaches an 85% threshold -- so adding a second path to the agent silently blinds
    the alarm that was already there.

    Requires the agent config to publish an ["InstanceId","path"] aggregation; without it these
    alarms sit in INSUFFICIENT_DATA.
  EOT
  type        = list(string)
  default     = []
}
