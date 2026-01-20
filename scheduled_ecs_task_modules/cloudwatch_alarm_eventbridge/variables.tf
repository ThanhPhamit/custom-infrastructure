variable "app_name" {
  description = "Application name"
  type        = string
}

variable "rule_name" {
  description = "EventBridge rule name to monitor"
  type        = string
}

variable "chatbot_alert_sns_topic_arn" {
  description = "SNS topic ARN for Chatbot alerts"
  type        = string
}

# Failed Invocations Configuration
variable "failed_invocations_period" {
  description = "Period for failed invocations alarm (seconds)"
  type        = number
  default     = 300
}

variable "failed_invocations_evaluation_periods" {
  description = "Evaluation periods for failed invocations alarm"
  type        = number
  default     = 1
}

variable "failed_invocations_threshold" {
  description = "Threshold for failed invocations"
  type        = number
  default     = 0
}

# Throttled Rules Configuration
variable "throttled_rules_period" {
  description = "Period for throttled rules alarm (seconds)"
  type        = number
  default     = 300
}

variable "throttled_rules_evaluation_periods" {
  description = "Evaluation periods for throttled rules alarm"
  type        = number
  default     = 1
}

variable "throttled_rules_threshold" {
  description = "Threshold for throttled rules"
  type        = number
  default     = 0
}

# Invocations Low Configuration
variable "enable_invocations_monitoring" {
  description = "Enable monitoring for low invocations (schedule heartbeat)"
  type        = bool
  default     = true
}

variable "invocations_low_period" {
  description = "Period for invocations low alarm (seconds) - should match expected schedule interval"
  type        = number
  default     = 3600 # 1 hour - adjust based on your schedule
}

variable "invocations_low_evaluation_periods" {
  description = "Evaluation periods for invocations low alarm"
  type        = number
  default     = 2
}

variable "invocations_low_threshold" {
  description = "Minimum expected invocations per period"
  type        = number
  default     = 1
}

# Invocation Errors Configuration
variable "invocation_errors_period" {
  description = "Period for invocation errors alarm (seconds)"
  type        = number
  default     = 300
}

variable "invocation_errors_evaluation_periods" {
  description = "Evaluation periods for invocation errors alarm"
  type        = number
  default     = 1
}

variable "invocation_errors_threshold" {
  description = "Threshold for invocation errors"
  type        = number
  default     = 0
}

# Dead Letter Queue Configuration
variable "enable_dlq_monitoring" {
  description = "Enable Dead Letter Queue monitoring"
  type        = bool
  default     = false
}

variable "dlq_name" {
  description = "Dead Letter Queue name (required if enable_dlq_monitoring is true)"
  type        = string
  default     = ""
}

variable "dlq_messages_period" {
  description = "Period for DLQ messages alarm (seconds)"
  type        = number
  default     = 300
}

variable "dlq_messages_evaluation_periods" {
  description = "Evaluation periods for DLQ messages alarm"
  type        = number
  default     = 1
}

variable "dlq_messages_threshold" {
  description = "Threshold for messages in DLQ"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
