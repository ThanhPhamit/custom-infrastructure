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
