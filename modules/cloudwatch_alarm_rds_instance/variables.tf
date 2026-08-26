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
    that disarms its actions while the instance is meant to be off (see the alarm_office_hours_gate module) --
    ungated it fires on every scheduled stop.

    ok_actions are deliberately empty: the gate's morning reset is an ALARM -> OK transition and
    would otherwise post to Slack every working day.
  EOT
  type        = bool
  default     = false
}
