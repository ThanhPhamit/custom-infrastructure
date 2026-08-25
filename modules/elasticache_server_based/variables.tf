variable "app_name" {}
variable "vpc_id" {}
variable "allowed_security_groups" {
  description = "List of security group IDs that are allowed to access the Redis instance"
  type        = list(string)
  default     = []
}
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ElastiCache subnet group (required if elasticache_subnet_group_name is not provided)"
  default     = []
}

variable "elasticache_subnet_group_name" {
  type        = string
  description = "Name of an existing ElastiCache subnet group (from network module). If provided, subnet_ids is not required."
  default     = null

  validation {
    condition     = var.elasticache_subnet_group_name != null || length(var.subnet_ids) > 0
    error_message = "Either elasticache_subnet_group_name or subnet_ids must be provided."
  }
}

variable "number_cache_clusters" {
  type = number
}

variable "cluster_mode" {
  type    = string
  default = "disabled"
}

variable "engine" {
  type    = string
  default = "redis"
}

variable "engine_version" {
  type    = string
  default = "7.0"
}

variable "node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "port" {
  type    = number
  default = 6379
}

variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}

variable "automatic_failover_enabled" {
  type    = bool
  default = false
}

variable "multi_az_enabled" {
  type    = bool
  default = false
}

variable "snapshot_window" {
  type    = string
  default = "17:00-18:00"
}

variable "snapshot_retention_limit" {
  type    = number
  default = 2
}

variable "maintenance_window" {
  type    = string
  default = "Sat:18:00-Sat:19:00"
}

variable "transit_encryption_enabled" {
  type    = bool
  default = false
}

variable "at_rest_encryption_enabled" {
  type    = bool
  default = false
}

variable "apply_immediately" {
  type    = bool
  default = true
}

variable "enable_cache_nodes_lookup" {
  type        = bool
  description = "Enable lookup of cache node details for CloudWatch alarms. Set to true after initial cluster creation."
  default     = false
}

variable "enable_log_delivery" {
  description = "If true, ship Redis/Valkey engine-log + slow-log to CloudWatch Logs. Required for ElastiCache versions 6.x+ (engine-log) / 6.0+ (slow-log)."
  type        = bool
  default     = false
}

variable "log_format" {
  description = "Format for CloudWatch Logs delivery. Either 'json' (structured, easier to query) or 'text' (smaller ingest volume)."
  type        = string
  default     = "json"

  validation {
    condition     = contains(["json", "text"], var.log_format)
    error_message = "log_format must be either 'json' or 'text'."
  }
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention applied to engine-log and slow-log groups."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 180, 365], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a valid CloudWatch retention value."
  }
}


variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "auth_token" {
  type        = string
  description = "AUTH token (password) clients must present to the cache. Requires transit_encryption_enabled = true. null disables AUTH. Pass from a Secrets Manager-backed value — never hardcode in tfvars."
  default     = null
  sensitive   = true
}

variable "auth_token_update_strategy" {
  type        = string
  description = "Strategy when rotating the AUTH token in place (ROTATE keeps the old token valid during rotation; SET replaces immediately)."
  default     = "ROTATE"

  validation {
    condition     = contains(["ROTATE", "SET"], var.auth_token_update_strategy)
    error_message = "auth_token_update_strategy must be ROTATE or SET."
  }
}
