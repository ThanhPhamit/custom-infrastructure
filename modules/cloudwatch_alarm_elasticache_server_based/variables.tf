variable "app_name" {
  description = "Application name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cache_nodes" {
  description = "Map of cache nodes with their details"
  type = map(object({
    address    = string
    az         = string
    cluster_id = string
    node_id    = string
    port       = number
  }))
}

variable "chatbot_notice_sns_topic_arn" {
  description = "SNS topic ARN for notice notifications"
  type        = string
}

variable "chatbot_alert_sns_topic_arn" {
  description = "SNS topic ARN for alert notifications"
  type        = string
}

# CPU Utilization thresholds
variable "cpu_utilization_warning_threshold" {
  description = "CPU utilization warning threshold"
  type        = number
  default     = 70
}

variable "cpu_utilization_critical_threshold" {
  description = "CPU utilization critical threshold"
  type        = number
  default     = 90
}

# Memory utilization thresholds
variable "database_memory_usage_warning_threshold" {
  description = "Database memory usage warning threshold"
  type        = number
  default     = 80
}

variable "database_memory_usage_critical_threshold" {
  description = "Database memory usage critical threshold"
  type        = number
  default     = 95
}

# # Cache hit ratio threshold
# variable "cache_hit_ratio_threshold" {
#   description = "Cache hit ratio threshold (below this triggers alarm)"
#   type        = number
#   default     = 80
# }

# # Connection count threshold
# variable "curr_connections_threshold" {
#   description = "Current connections threshold"
#   type        = number
#   default     = 100
# }

# # Evictions threshold
# variable "evictions_threshold" {
#   description = "Evictions threshold"
#   type        = number
#   default     = 10
# }

# # Network thresholds
# variable "network_bytes_in_threshold" {
#   description = "Network bytes in threshold (bytes per second)"
#   type        = number
#   default     = 10000000 # 10MB
# }

# variable "network_bytes_out_threshold" {
#   description = "Network bytes out threshold (bytes per second)"
#   type        = number
#   default     = 10000000 # 10MB
# }

# # Replication lag threshold
# variable "replication_lag_threshold" {
#   description = "Replication lag threshold in seconds"
#   type        = number
#   default     = 30
# }

# Alarm evaluation periods
variable "evaluation_periods" {
  description = "Number of evaluation periods for warning alarms"
  type        = number
  default     = 5
}

variable "period" {
  description = "Period in seconds for warning alarms"
  type        = number
  default     = 60
}

# New variables for critical alarms
variable "critical_evaluation_periods" {
  description = "Number of evaluation periods for critical alarms"
  type        = number
  default     = 1 # Immediate response
}

variable "critical_period" {
  description = "Period in seconds for critical alarms"
  type        = number
  default     = 60 # 1 minute
}

variable "critical_datapoints_to_alarm" {
  description = "Number of datapoints to alarm for critical alarms"
  type        = number
  default     = 1 # Single breach triggers alarm
}

# Optional: separate datapoints_to_alarm for warnings
variable "datapoints_to_alarm" {
  description = "Number of datapoints to alarm for warning alarms"
  type        = number
  default     = 2 # Reduce false positives
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
