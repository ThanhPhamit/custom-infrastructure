variable "app_name" {
  description = "Application name for resource naming"
  type        = string
}

variable "acm_certificate_arn" {
  description = <<-EOT
    ACM certificate ARN for CloudFront (must be in us-east-1). Required only
    when `domains` is non-empty; pass null to skip custom domains entirely
    and fall back to the default `*.cloudfront.net` certificate.
  EOT
  type        = string
  default     = null
}

variable "route_53_zone_id" {
  description = <<-EOT
    Route53 hosted zone ID. Required only when `domains` is non-empty so the
    module can create alias records. Pass null when running without custom
    domains.
  EOT
  type        = string
  default     = null
}

variable "domains" {
  description = <<-EOT
    Custom domain names for the frontend. All domains share the same S3
    bucket + CloudFront distribution. Leave empty `[]` to serve from the
    default `*.cloudfront.net` URL — useful for internal tools that don't
    need a vanity domain.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.domains) == 0 || (var.acm_certificate_arn != null && var.route_53_zone_id != null)
    error_message = "When `domains` is non-empty, both `acm_certificate_arn` and `route_53_zone_id` must be provided."
  }
}

variable "enable_spa_router" {
  description = <<-EOT
    DEPRECATED — prefer `routing_mode`. Kept for backward compatibility:
      `enable_spa_router = true`  → routing_mode = "spa"   (everything → /index.html)
      `enable_spa_router = false` → routing_mode = "none"
    Ignored when `routing_mode` is set explicitly.
  EOT
  type        = bool
  default     = true
}

variable "routing_mode" {
  description = <<-EOT
    URL-rewrite strategy for the CloudFront distribution. Choose the mode
    that matches how your bundler emits HTML:

      "spa"    — single `/index.html` + client-side router (Vue / React /
                 Angular / CRA / Vite). Rewrites everything without an
                 extension OR ending in `/` to `/index.html`. Same behaviour
                 as the legacy `enable_spa_router = true`.

      "nextjs" — Next.js `output: "export"` (one pre-rendered HTML per route
                 at `/route/index.html`). Rewrites `/login/` → `/login/index.html`
                 and `/tenants` → `/tenants/index.html`. Each route renders
                 its own HTML — no client-side redirect dance, no spinner
                 deadlock when the home page's redirect target equals the
                 current URL.

      "none"   — no rewrite. Useful for plain static sites where every
                 requested object exists in S3 as-is.

    Leave null to fall back to the deprecated `enable_spa_router` flag.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.routing_mode == null || contains(["spa", "nextjs", "none"], var.routing_mode)
    error_message = "routing_mode must be one of: spa, nextjs, none."
  }
}

variable "create_cloudfront_function" {
  description = "Whether to create the CloudFront function for basic auth"
  type        = bool
  default     = true
}

variable "canonical_domain" {
  description = <<-EOT
    When set, any request whose Host header doesn't match this value is
    301-redirected to `https://<canonical_domain><uri>`. Use it to enforce a
    single canonical domain (e.g. send `www.example.com` to `example.com`).

    Only honoured for `routing_mode = "nextjs"`; combining canonical-redirect
    with `spa` / `none` modes isn't implemented yet because they share the same
    CloudFront function slot.
  EOT
  type        = string
  default     = null
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
