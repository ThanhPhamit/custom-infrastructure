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

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
