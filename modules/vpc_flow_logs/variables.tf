variable "app_name" {
  description = "Naming prefix (e.g. myapp-prod)."
  type        = string
}

variable "vpc_id" {
  description = "VPC to capture flow logs for."
  type        = string
}

variable "traffic_type" {
  description = "Which traffic to log: ALL (recommended — needed to spot egress exfil), ACCEPT, or REJECT."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.traffic_type)
    error_message = "traffic_type must be ALL, ACCEPT, or REJECT."
  }
}

variable "retention_days" {
  description = "CloudWatch Logs retention for the flow logs."
  type        = number
  default     = 30
}

variable "max_aggregation_interval" {
  description = "Seconds over which a flow is aggregated into one record: 600 (10 min, fewer records/cheaper) or 60 (1 min, finer)."
  type        = number
  default     = 600

  validation {
    condition     = contains([60, 600], var.max_aggregation_interval)
    error_message = "max_aggregation_interval must be 60 or 600."
  }
}

variable "log_kms_key_id" {
  description = "Optional CMK ARN to encrypt the flow-log group. null = default CloudWatch Logs encryption."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}
