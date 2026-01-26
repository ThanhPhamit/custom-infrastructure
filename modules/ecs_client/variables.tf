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

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks. Must be created externally to avoid cycle dependencies with RDS/ElastiCache."
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

variable "elasticache_security_group_id" {
  type        = string
  description = "Security group ID for the ElastiCache cluster"
}
variable "elasticache_primary_endpoint_port" {
  type        = number
  description = "Primary endpoint port for the ElastiCache cluster"
}

# Enviroment variables
