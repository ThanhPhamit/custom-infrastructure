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

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to ECS tasks (required when running in public subnets without NAT Gateway)"
  default     = false
}
variable "repository_arn" {
  type        = string
  description = "The ARN of the ECR repository"
}

variable "cloudwatch_log_retention_in_days" {
  type        = number
  description = "Number of days to retain ECS CloudWatch logs"
  default     = 30

  validation {
    condition     = var.cloudwatch_log_retention_in_days >= 1 && var.cloudwatch_log_retention_in_days <= 3653
    error_message = "cloudwatch_log_retention_in_days must be between 1 and 3653 days."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "secret_arns" {
  type        = list(string)
  description = "Additional Secrets Manager secret ARNs the task execution role may read — e.g. externally-managed secrets referenced by the task definition's `secrets` entries (registered by CI/CD via taskdef.json). Combined with the managed app-secret container when `create_app_secret = true`. Empty list (and create_app_secret = false) = no Secrets Manager statement in the execution policy."
  default     = []
}

variable "create_app_secret" {
  type        = bool
  description = <<-EOT
    Create a single empty Secrets Manager container named "<app_name>-secrets" for
    the app's runtime secrets. The container-only model: Terraform creates just the
    container and grants the task read access — it NEVER generates or reads any
    secret value, so nothing sensitive is stored in Terraform state. Populate the
    JSON value out-of-band (console or a gitignored file; see secrets.example.json).
    The execution role is automatically granted read access to it and its ARN is
    exposed via the `app_secrets_arn` output for the task definition's `secrets`
    entries (valueFrom = "<arn>:<key>::"). Leave false to manage secrets purely via
    `secret_arns`.
  EOT
  default     = false
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture for the Fargate runtime platform. ARM64 (Graviton) is ~20% cheaper than X86_64 — the container image must be built for the matching architecture."
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

# Enviroment variables
