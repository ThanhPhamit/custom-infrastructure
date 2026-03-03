# ---------------------------------------------------------------------------
# Required
# ---------------------------------------------------------------------------

variable "app_name" {
  description = "Application name used as a prefix for all resource names."
  type        = string
}

variable "scope" {
  description = "WAF scope: CLOUDFRONT (Global/CDN) or REGIONAL (ALB, API Gateway, AppSync). CLOUDFRONT requires provider region = us-east-1."
  type        = string
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "scope must be either \"CLOUDFRONT\" or \"REGIONAL\"."
  }
}

variable "service_type" {
  description = <<-EOT
    Target service type. Determines which rules are enabled by default (preset).
    Any individual enable_* variable set explicitly will override the preset.
      CLOUDFRONT  – CDN edge (Anonymous IP + Known Bad Inputs on, rate_limit=5000)
      ALB         – Web application (SQLi + Body Size + Known Bad Inputs on)
      API_GATEWAY – REST API (stricter rate_limit=1000, SQLi + Body Size + Known Bad Inputs)
      APPSYNC     – GraphQL (SQLi + Known Bad Inputs on)
      COGNITO     – Auth (strict rate_limit=500, Anonymous IP + Bot Control on)
      APP_RUNNER  – Container service (SQLi + Body Size + Known Bad Inputs on)
      CUSTOM      – All optional rules off; configure each enable_* flag yourself.
  EOT
  type        = string
  default     = "CUSTOM"
  validation {
    condition     = contains(["CLOUDFRONT", "ALB", "API_GATEWAY", "APPSYNC", "COGNITO", "APP_RUNNER", "CUSTOM"], var.service_type)
    error_message = "service_type must be one of: CLOUDFRONT, ALB, API_GATEWAY, APPSYNC, COGNITO, APP_RUNNER, CUSTOM."
  }
}

# ---------------------------------------------------------------------------
# Always-on rule settings
# ---------------------------------------------------------------------------

variable "rate_limit_override" {
  description = "Override the preset rate limit. Set to null to use the service_type default."
  type        = number
  default     = null
}

variable "log_retention" {
  description = "Number of days to retain WAF logs in the CloudWatch log group."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Optional: IP Allowlist (priority 10)
# Always user-controlled – no preset logic. Default: off.
# ---------------------------------------------------------------------------

variable "enable_ip_allowlist" {
  description = "Enable an IP allowlist rule that always allows requests from trusted IPs."
  type        = bool
  default     = false
}

variable "allowed_ip_addresses" {
  description = "List of IPv4 CIDR blocks to always allow. Only used when enable_ip_allowlist = true."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Optional: Geo-blocking (priority 20)
# Always user-controlled – no preset logic. Default: off.
# ---------------------------------------------------------------------------

variable "enable_geo_block" {
  description = "Enable a geo-blocking rule to drop traffic from specified countries."
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "ISO 3166-1 alpha-2 country codes to block (e.g. [\"CN\", \"RU\"]). Only used when enable_geo_block = true."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Optional: Anonymous IP List (priority 30)
# Set to null → use service_type preset. Set true/false → override.
# ---------------------------------------------------------------------------

variable "enable_anonymous_ip_list" {
  description = "Enable the AWS-managed AWSManagedRulesAnonymousIpList rule. null = use service_type preset."
  type        = bool
  default     = null
}

# ---------------------------------------------------------------------------
# Optional: Body size restriction (priority 60)
# Set to null → use service_type preset. Set true/false → override.
# ---------------------------------------------------------------------------

variable "enable_body_size_restriction" {
  description = "Enable a rule that blocks requests with a body > max_body_size_bytes. null = use service_type preset."
  type        = bool
  default     = null
}

variable "max_body_size_bytes" {
  description = "Maximum request body size in bytes. Only used when body size restriction is active."
  type        = number
  default     = 8192 # 8 KB
}

# ---------------------------------------------------------------------------
# Optional: SQL Injection protection (priority 70)
# Set to null → use service_type preset. Set true/false → override.
# ---------------------------------------------------------------------------

variable "enable_sql_injection_protection" {
  description = "Enable the AWS-managed AWSManagedRulesSQLiRuleSet. null = use service_type preset."
  type        = bool
  default     = null
}

# ---------------------------------------------------------------------------
# Optional: Known Bad Inputs (priority 80)
# Set to null → use service_type preset. Set true/false → override.
# ---------------------------------------------------------------------------

variable "enable_known_bad_inputs" {
  description = "Enable the AWS-managed AWSManagedRulesKnownBadInputsRuleSet. null = use service_type preset."
  type        = bool
  default     = null
}

# ---------------------------------------------------------------------------
# Optional: Bot Control (priority 90)
# Set to null → use service_type preset. Set true/false → override.
# WARNING: additional AWS cost (~$10/month + per-request fee).
# ---------------------------------------------------------------------------

variable "enable_bot_control" {
  description = "Enable the AWS-managed AWSManagedRulesBotControlRuleSet. null = use service_type preset. Note: extra AWS cost."
  type        = bool
  default     = null
}

variable "bot_control_inspection_level" {
  description = "Bot Control inspection level: COMMON (cheaper) or TARGETED (deeper, higher cost)."
  type        = string
  default     = "COMMON"
  validation {
    condition     = contains(["COMMON", "TARGETED"], var.bot_control_inspection_level)
    error_message = "bot_control_inspection_level must be COMMON or TARGETED."
  }
}

# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
