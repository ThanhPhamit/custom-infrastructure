variable "app_name" {
  description = "Application name for resource naming"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}

variable "route_53_zone_id" {
  description = "Route53 hosted zone ID for DNS record"
  type        = string
}

variable "domain" {
  description = "Custom domain name for the frontend (e.g., www.example.com)"
  type        = string
}

variable "create_cloudfront_function" {
  description = "Whether to create the CloudFront function for basic auth"
  type        = bool
  default     = true
}

variable "basic_auth_password" {
  description = "Password for basic auth. Username will be the app_name."
  type        = string
  default     = ""
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class. Use PriceClass_200 for Asia/Europe/US, PriceClass_100 for US/Europe only"
  type        = string
  default     = "PriceClass_All"
}

variable "default_root_object" {
  description = "Default root object (index file)"
  type        = string
  default     = "index.html"
}

variable "spa_mode" {
  description = "Enable SPA mode (redirect 403/404 to index.html for client-side routing)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
