variable "app_name" {}
variable "region" {
  type = string
}
variable "container_names" {
  type        = list(string)
  description = "Names of the containers to run in the task"
}
variable "container_port" {
  type        = number
  description = "The port number on the container"
}
variable "vpc_id" {}
variable "cluster_name" {}
variable "http_prod_listener_arn" {
  description = "ARN of the production listener (ALB or NLB)"
  type        = string
}
variable "http_test_listener_arn" {
  description = "ARN of the test listener (ALB or NLB)"
  type        = string
}
variable "alb_security_group_id" {
  description = "Security group ID of the load balancer"
  type        = string
}

variable "load_balancer_type" {
  description = "Type of load balancer (alb or nlb)"
  type        = string
  default     = "alb"
  validation {
    condition     = contains(["alb", "nlb"], var.load_balancer_type)
    error_message = "Load balancer type must be either 'alb' or 'nlb'."
  }
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer (required when load_balancer_type is 'nlb')"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for TLS termination (required when load_balancer_type is 'nlb')"
  type        = string
  default     = null
}

variable "subnet_ids" {}
variable "desired_task_count" {}
variable "task_cpu_size" {}
variable "task_memory_size" {}
variable "app_health_check_path" {}
variable "repository_url" {}
variable "repository_arn" {
  type        = string
  description = "The ARN of the ECR repository"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

# Enviroment variables
variable "db_host" {
  type        = string
  description = "Database host"
}
variable "db_port" {
  type        = number
  description = "Database port"
}
variable "db_user" {
  type        = string
  description = "Database user"
}
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}
variable "db_name" {
  type        = string
  description = "Database name"
}
variable "db_schema" {
  type        = string
  description = "Database schema"
}
variable "db_timezone" {
  type        = string
  description = "Database timezone"
}
variable "white_list" {
  type = string
}
variable "jwt_algorithm" {
  type        = string
  description = "JWT algorithm"
}
variable "jwt_expires_in" {
  type        = string
  description = "JWT expiration time"
}
variable "refresh_token_expires_in" {
  type        = string
  description = "Refresh token expiration time"
}
variable "crypto_algorithm" {
  type        = string
  description = "Cryptographic algorithm"
}
variable "redis_url" {
  type        = string
  description = "Redis URL"
}
variable "queue_host" {
  type        = string
  description = "Queue host"
}
variable "queue_port" {
  type        = number
  description = "Queue port"
}
variable "http_timeout" {
  type = number
}
variable "http_max_redirects" {
  type = number
}
variable "wcs_robot_api_url" {
  type = string
}
variable "wcs_max_robot_call_queue" {
  type = number
}
variable "wcs_robot_ids" {
  type        = string
  default     = ""
  description = "Comma-separated list of WCS robot IDs"
}


variable "elasticache_security_group_id" {
  type        = string
  description = "Security group ID for the ElastiCache cluster"
}
variable "elasticache_primary_endpoint_port" {
  type        = number
  description = "Primary endpoint port for the ElastiCache cluster"
}
