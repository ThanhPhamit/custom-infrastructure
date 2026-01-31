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

# =============================================================================
# Environment Variables (Non-sensitive)
# =============================================================================

variable "environment" {
  type        = string
  description = "Environment name (e.g., LOCAL, PRODUCTION)"
  default     = "PRODUCTION"
}

variable "allowed_hosts" {
  type        = string
  description = "Comma-separated list of allowed hosts"
  default     = "0.0.0.0,localhost,127.0.0.1"
}

variable "error_code_prefix" {
  type        = string
  description = "Prefix for error codes"
  default     = "RCL"
}

variable "time_zone" {
  type        = string
  description = "Application timezone"
  default     = "Asia/Tokyo"
}

variable "cors_allowed_origins" {
  type        = string
  description = "Comma-separated list of CORS allowed origins"
}

variable "client_server" {
  type        = string
  description = "Client server URL"
}

# Database Configuration
variable "postgres_host" {
  type        = string
  description = "Database host endpoint"
}

variable "postgres_port" {
  type        = number
  description = "Database port"
  default     = 5432
}

variable "postgres_db" {
  type        = string
  description = "Database name"
}

variable "postgres_user" {
  type        = string
  description = "Database username"
}

variable "postgres_schema" {
  type        = string
  description = "Database schema"
  default     = "public"
}

# Cache Configuration
variable "cache_host" {
  type        = string
  description = "Redis/Valkey cache host endpoint"
}

variable "cache_port" {
  type        = number
  description = "Cache port"
  default     = 6379
}

# JWT Configuration
variable "jwt_algorithms" {
  type        = string
  description = "JWT algorithms"
  default     = "HS256"
}

variable "jwt_expires" {
  type        = string
  description = "JWT expiration time"
  default     = "7d"
}

variable "jwt_refresh_expires" {
  type        = string
  description = "JWT refresh token expiration time"
  default     = "7d"
}

# GMO Payment Configuration
variable "gmo_prefix_member" {
  type        = string
  description = "GMO member prefix"
}

variable "gmo_site_id" {
  type        = string
  description = "GMO Site ID"
}

variable "gmo_shop_id" {
  type        = string
  description = "GMO Shop ID"
}

variable "dev_gmo_base_url" {
  type        = string
  description = "GMO payment base URL"
  default     = "https://pt01.mul-pay.jp/payment/"
}

variable "prod_gmo_base_url" {
  type        = string
  description = "GMO payment base URL"
  default     = "https://pt01.mul-pay.jp/payment/"
}

# Email/SMTP Configuration
variable "email_host" {
  type        = string
  description = "SMTP host"
  default     = "email-smtp.ap-northeast-1.amazonaws.com"
}

variable "email_port" {
  type        = string
  description = "SMTP port"
  default     = "587"
}

variable "email_use_tls" {
  type        = bool
  description = "Use TLS for SMTP"
  default     = true
}

variable "default_from_email" {
  type        = string
  description = "Default from email address"
}

# Twilio Configuration
variable "twilio_account_sid" {
  type        = string
  description = "Twilio Account SID"
  default     = ""
}
variable "twilio_service_messaging_sid" {
  type        = string
  description = "Twilio Service Messaging SID"
  default     = ""
}

variable "phone_code" {
  type        = string
  description = "Default phone country code"
  default     = "+81"
}

# Tax & Invoice Configuration
variable "tax" {
  type        = number
  description = "Tax rate percentage"
  default     = 10
}

variable "invoice_tax" {
  type        = number
  description = "Invoice tax rate percentage"
  default     = 10
}

variable "order_prefix" {
  type        = string
  description = "Order ID prefix"
  default     = "ORD"
}

variable "consulting_prefix" {
  type        = string
  description = "Consulting ID prefix"
  default     = "CST"
}

variable "invoice_prefix" {
  type        = string
  description = "Invoice ID prefix"
  default     = "INV"
}

variable "invoice_range_days" {
  type        = number
  description = "Invoice range days"
  default     = 30
}

# AWS Configuration
variable "aws_bucket" {
  type        = string
  description = "S3 bucket name for file storage"
}

variable "aws_bucket_region" {
  type        = string
  description = "S3 bucket region"
  default     = "ap-northeast-1"
}

variable "aws_prefix_file_name" {
  type        = string
  description = "S3 file name prefix"
  default     = "rmc"
}

variable "aws_chime_default_region" {
  type        = string
  description = "AWS Chime default region"
  default     = "ap-northeast-1"
}

variable "debug" {
  type        = bool
  description = "Enable debug mode"
  default     = false
}

variable "http_x_forwarded_proto" {
  type        = string
  description = "HTTP X-Forwarded-Proto header value"
  default     = "https"
}

# Inquiry Emails
variable "inquiry_payment_email" {
  type        = string
  description = "Inquiry email for payment issues"
  default     = ""
}

variable "inquiry_online_clinic_service_email" {
  type        = string
  description = "Inquiry email for service issues"
  default     = ""
}

variable "inquiry_other_email" {
  type        = string
  description = "Inquiry email for other issues"
  default     = ""
}

variable "inquiry_email_cc_to" {
  type        = string
  description = "CC email for inquiries"
  default     = ""
}

# =============================================================================
# Secrets (Sensitive - passed from outside, stored in AWS Secrets Manager)
# =============================================================================

# Database
variable "postgres_password_secret_arn" {
  type        = string
  description = "ARN of the database password secret in Secrets Manager"
}

# GMO Payment
variable "gmo_site_pass" {
  type        = string
  description = "GMO Site Pass (will be stored in Secrets Manager)"
  sensitive   = true
  default     = ""
}

variable "gmo_shop_pass" {
  type        = string
  description = "GMO Shop Pass (will be stored in Secrets Manager)"
  sensitive   = true
  default     = ""
}

# SES SMTP
variable "email_host_user_secret_arn" {
  type        = string
  description = "ARN of the SES SMTP username secret in Secrets Manager"
}

variable "email_host_password_secret_arn" {
  type        = string
  description = "ARN of the SES SMTP password secret in Secrets Manager"
}

# Twilio
variable "twilio_auth_token" {
  type        = string
  description = "Twilio Auth Token (will be stored in Secrets Manager)"
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Auto-generated Secrets (Terraform creates these automatically):
# - ADMIN_SECRET_KEY
# - SECRET_KEY
# - JWT_SECRET_KEY
# - JWT_REFRESH_SECRET_KEY
# - CRYPTO_SECRET_KEY
# -----------------------------------------------------------------------------
