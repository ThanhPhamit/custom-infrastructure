variable "app_name" {
  description = "Application name"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for the ECS task"
  type        = string
}

variable "chatbot_alert_sns_topic_arn" {
  description = "SNS topic ARN for Chatbot alerts"
  type        = string
}

# ============================================
# Task Failure Monitoring Configuration
# ============================================

variable "enable_task_failure_monitoring" {
  description = "Enable task failure monitoring via application log errors"
  type        = bool
  default     = true
}

variable "task_failure_log_pattern" {
  description = "CloudWatch Logs filter pattern for task failures - matches ERROR, CRITICAL, Exception"
  type        = string
  default     = "?ERROR ?CRITICAL ?Exception ?Traceback ?\"❌\""
}

variable "task_failed_period" {
  description = "Period for task failed alarm (seconds)"
  type        = number
  default     = 300
}

variable "task_failed_evaluation_periods" {
  description = "Evaluation periods for task failed alarm"
  type        = number
  default     = 1
}

variable "task_failed_threshold" {
  description = "Threshold for task failed alarm (number of errors)"
  type        = number
  default     = 0
}

# CPU Utilization Configuration
variable "cpu_period" {
  description = "Period for CPU utilization alarm (seconds)"
  type        = number
  default     = 300
}

variable "cpu_evaluation_periods" {
  description = "Evaluation periods for CPU utilization alarm"
  type        = number
  default     = 2
}

variable "cpu_high_threshold" {
  description = "Threshold for high CPU utilization (%)"
  type        = number
  default     = 80
}

# Memory Utilization Configuration
variable "memory_period" {
  description = "Period for memory utilization alarm (seconds)"
  type        = number
  default     = 300
}

variable "memory_evaluation_periods" {
  description = "Evaluation periods for memory utilization alarm"
  type        = number
  default     = 2
}

variable "memory_high_threshold" {
  description = "Threshold for high memory utilization (%)"
  type        = number
  default     = 80
}

# Log Error Monitoring Configuration
variable "enable_log_error_monitoring" {
  description = "Enable log error monitoring"
  type        = bool
  default     = true
}

variable "log_error_pattern" {
  description = "Pattern to match errors in logs"
  type        = string
  default     = "?ERROR ?CRITICAL ?Exception"
}

variable "log_error_period" {
  description = "Period for log error alarm (seconds)"
  type        = number
  default     = 300
}

variable "log_error_evaluation_periods" {
  description = "Evaluation periods for log error alarm"
  type        = number
  default     = 1
}

variable "log_error_threshold" {
  description = "Threshold for log errors count"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
