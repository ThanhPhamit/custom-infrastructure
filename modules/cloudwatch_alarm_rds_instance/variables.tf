variable "app_name" {}
variable "rds_db_instance_identifier" {}
variable "cw_alarm_rds_default_period" {}
variable "cw_alarm_rds_default_evaluation_periods" {}
variable "cw_alarm_rds_cpu_utilization_notice_threshold" {}
variable "cw_alarm_rds_cpu_utilization_alert_threshold" {}
variable "cw_alarm_rds_freeable_memory_notice_threshold" {}
variable "cw_alarm_rds_freeable_memory_alert_threshold" {}
variable "cw_alarm_rds_freeable_storage_space_notice_threshold" {}
variable "cw_alarm_rds_freeable_storage_space_alert_threshold" {}

variable "chatbot_notice_sns_topic_arn" {}
variable "chatbot_alert_sns_topic_arn" {}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "create_instance_absent_alarm" {
  description = <<-EOT
    Create an alarm that fires when the DB instance publishes NO metrics at all -- it is stopped,
    deleted, or failed to start. The six threshold alarms above cannot answer this: they run
    treat_missing_data = "missing", so a stopped instance takes them to INSUFFICIENT_DATA and
    notifies nobody.

    Only useful on an instance with a start/stop schedule, and only alongside an office-hours gate
    that disarms its actions while the instance is meant to be off (see alarm_office_hours_gate) --
    ungated it fires on every scheduled stop.

    ok_actions are deliberately empty: the gate's morning reset is an ALARM -> OK transition and
    would otherwise post to Slack every working day.
  EOT
  type        = bool
  default     = false
}

variable "create_schedule_overrun_alarm" {
  description = <<-EOT
    Create an alarm that fires when the DB instance ran for MORE minutes in a day than its schedule
    allows -- a stop that silently did not happen. Needs no office-hours gate because it counts
    rather than samples: CPUUtilization publishes exactly one datapoint per minute while the instance
    lives, so the daily SampleCount IS the number of minutes it ran.

    A 13h25 weekday window is 805 datapoints; an instance that never stopped is 1440. Weekends
    produce no data, hence treat_missing_data = notBreaching -- absence is the good case.
  EOT
  type        = bool
  default     = false
}

variable "schedule_overrun_max_minutes_per_day" {
  description = "Minutes per day above which the instance is considered to have overrun its schedule. Set comfortably above the real window and below 1440."
  type        = number
  default     = 1000

  validation {
    condition     = var.schedule_overrun_max_minutes_per_day > 0 && var.schedule_overrun_max_minutes_per_day < 1440
    error_message = "schedule_overrun_max_minutes_per_day must be between 1 and 1439 (1440 = always on, which can never breach)."
  }
}
