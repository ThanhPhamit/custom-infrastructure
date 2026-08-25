variable "app_name" {
  description = "Application name"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB domain name (DNS name from ALB)"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for CloudFront distribution (e.g., cdn.example.com)"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "route_53_zone_id" {
  description = "Route 53 hosted zone ID for custom domain"
  type        = string
  default     = ""
}

# Cache behavior settings
variable "cache_policy_id" {
  description = "ID of an existing CloudFront cache policy. If not provided, a custom policy will be created."
  type        = string
  default     = ""
}

variable "origin_request_policy_id" {
  description = "ID of an existing CloudFront origin request policy. If not provided, a custom policy will be created."
  type        = string
  default     = ""
}

variable "response_headers_policy_id" {
  description = "ID of an existing CloudFront response headers policy (optional)"
  type        = string
  default     = ""
}

variable "forwarded_headers" {
  description = "List of headers to forward to origin"
  type        = list(string)
  default     = ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Desktop-Viewer", "CloudFront-Is-Mobile-Viewer", "CloudFront-Is-Tablet-Viewer"]
}

variable "min_ttl" {
  description = "Minimum TTL for cache behavior"
  type        = number
  default     = 0
}

variable "default_ttl" {
  description = "Default TTL for cache behavior"
  type        = number
  default     = 300
}

variable "max_ttl" {
  description = "Maximum TTL for cache behavior"
  type        = number
  default     = 31536000
}

variable "cache_behaviors" {
  description = "Additional cache behaviors for specific paths"
  type = list(object({
    path_pattern               = string
    allowed_methods            = list(string)
    cached_methods             = list(string)
    cache_policy_id            = optional(string, "")
    origin_request_policy_id   = optional(string, "")
    response_headers_policy_id = optional(string, "")
    enable_auth                = optional(bool, false)
  }))
  default = []

  # Example:
  # [
  #   {
  #     path_pattern               = "/admin/*"
  #     allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  #     cached_methods             = ["GET", "HEAD"]
  #     cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
  #     origin_request_policy_id   = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewerExceptHost
  #     response_headers_policy_id = ""
  #     enable_auth                = false
  #   },
  #   {
  #     path_pattern               = "/api/*"
  #     allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  #     cached_methods             = ["GET", "HEAD"]
  #     cache_policy_id            = ""
  #     origin_request_policy_id   = ""
  #     response_headers_policy_id = ""
  #     enable_auth                = false
  #   }
  # ]
}

# Geographic restrictions
variable "geo_restriction_type" {
  description = "Type of geographic restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geographic restrictions"
  type        = list(string)
  default     = []
}

# Price class
variable "price_class" {
  description = <<-EOT
    CloudFront price class - controls which edge locations are used:
    - PriceClass_100: USA, Canada, Europe, & Israel
    - PriceClass_200: PriceClass_100 + South Africa, Kenya, Middle East, Japan, Singapore, South Korea, Taiwan, Hong Kong, & Philippines
    - PriceClass_All: All locations worldwide
  EOT
  type        = string
  default     = "PriceClass_All"
}

# Logging
variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront access logs"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for CloudFront access log files"
  type        = string
  default     = "cloudfront-logs/"
}

# IPv6 support
variable "enable_ipv6" {
  description = "Enable IPv6 support"
  type        = bool
  default     = true
}

# Basic authentication (optional)
variable "enable_default_auth" {
  description = "Enable basic authentication using Lambda@Edge"
  type        = bool
  default     = false
}

variable "basic_auth_username" {
  description = "Username for basic authentication"
  type        = string
  default     = "admin"
}

variable "basic_auth_password" {
  description = "Password for basic authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL to associate with this CloudFront distribution. Must be created in us-east-1 with scope=CLOUDFRONT. Leave empty to disable WAF."
  type        = string
  default     = ""
}

variable "origin_client_certificate_arn" {
  description = "Origin mTLS: ACM certificate ARN (us-east-1, EKU clientAuth) CloudFront presents to the origin on every origin TLS handshake; the origin verifies it. REQUIRED BY POLICY whenever this distribution fronts a PUBLIC origin you control (ALB/custom origin) — a CloudFront prefix list or shared-secret header alone is NOT sufficient access control. Empty string disables it (kept for backward-compat / S3-style origins only). NOT used when enable_vpc_origin = true (a private origin needs no mTLS lock). Requires aws provider >= 6.51.0."
  type        = string
  default     = ""
}

variable "enable_vpc_origin" {
  description = "Reach the origin through a CloudFront VPC origin instead of a public custom origin. PREFERRED whenever the origin lives in a VPC (standing preference): point this at an INTERNAL ALB — the origin then has no public IP at all, which replaces the origin-mTLS lock entirely. alb_domain_name must still resolve/match the internal ALB's certificate. Requires vpc_origin_endpoint_arn."
  type        = bool
  default     = false
}

variable "vpc_origin_endpoint_arn" {
  description = "ARN of the internal ALB (or NLB / EC2 instance) the VPC origin connects to. Required when enable_vpc_origin = true."
  type        = string
  default     = ""
}

variable "vpc_origin_https_port" {
  description = "HTTPS port CloudFront connects to on the VPC origin endpoint."
  type        = number
  default     = 443
}

variable "vpc_origin_protocol_policy" {
  description = "Protocol policy for the VPC origin connection."
  type        = string
  default     = "https-only"
  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.vpc_origin_protocol_policy)
    error_message = "vpc_origin_protocol_policy must be one of: http-only, https-only, match-viewer."
  }
}

variable "vpc_origin_ssl_protocols" {
  description = "SSL/TLS protocols CloudFront may use when connecting to the VPC origin."
  type        = list(string)
  default     = ["TLSv1.2"]
}
