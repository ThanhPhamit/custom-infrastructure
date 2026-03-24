# ---------------------------------------------------------------------------
# Required
# ---------------------------------------------------------------------------

variable "app_name" {
  description = "Application name (must match waf_standard app_name for metric correlation)."
  type        = string
}

variable "scope" {
  description = "WAF scope: CLOUDFRONT or REGIONAL."
  type        = string
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "scope must be either \"CLOUDFRONT\" or \"REGIONAL\"."
  }
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications. Typically provided by the alert_email module."
  type        = string
}

variable "web_acl_arn" {
  description = "ARN of the WAF Web ACL to attach logging configuration to."
  type        = string
}

variable "active_rules" {
  description = "Map of active rule keys to their metric name and action mode. Pass from waf_standard active_rules output."
  type = map(object({
    metric_name = string
    action_mode = string
  }))
}

# ---------------------------------------------------------------------------
# S3 Full Logging
# ---------------------------------------------------------------------------

variable "s3_log_retention_days" {
  description = "Total days to retain WAF full logs in S3 before deletion."
  type        = number
  default     = 365
}

variable "s3_transition_ia_days" {
  description = "Days before transitioning logs to STANDARD_IA storage class."
  type        = number
  default     = 30
}

variable "s3_transition_glacier_days" {
  description = "Days before transitioning logs to GLACIER storage class."
  type        = number
  default     = 90
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms
# ---------------------------------------------------------------------------

variable "alarm_blocked_requests_threshold" {
  description = "Threshold for blocked requests alarms (sum per evaluation period)."
  type        = number
  default     = 100
}

variable "alarm_counted_requests_threshold" {
  description = "Threshold for counted requests alarms (sum per evaluation period)."
  type        = number
  default     = 500
}

variable "alarm_rate_limit_threshold" {
  description = "Threshold for rate limit rule alarms (sum per evaluation period)."
  type        = number
  default     = 50
}

variable "alarm_evaluation_periods" {
  description = "Number of consecutive periods the metric must breach to trigger alarm."
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "Evaluation period in seconds for CloudWatch alarms."
  type        = number
  default     = 300
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

variable "enable_dashboard" {
  description = "Create a CloudWatch dashboard for WAF metrics visualization."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Athena
# ---------------------------------------------------------------------------

variable "enable_athena" {
  description = "Create Athena workgroup, Glue database/table, and S3 results bucket for querying WAF logs."
  type        = bool
  default     = true
}

variable "athena_results_retention_days" {
  description = "Days to retain Athena query results in S3 before auto-deletion."
  type        = number
  default     = 7
}

variable "athena_bytes_scanned_limit" {
  description = "Maximum bytes a single Athena query can scan. Queries exceeding this limit are cancelled. (1 GB = 1073741824)"
  type        = number
  default     = 1073741824 # 1 GB
}

# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
