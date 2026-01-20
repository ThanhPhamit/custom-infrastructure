# Network Module - Sample Usage

## main.tf

```terraform
module "cloudfront_client" {
  source = "../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-client"
  alb_domain_name = module.elb_client.domain

  # Use the same domain as ALB for CloudFront custom domain
  custom_domain       = var.elb_client_alb_domain
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.this.id

  # Cache settings optimized for web applications
  min_ttl     = 0
  default_ttl = 300   # 5 minutes
  max_ttl     = 86400 # 24 hours
  forwarded_headers = [
    "Host",
    "CloudFront-Forwarded-Proto",
    "CloudFront-Is-Desktop-Viewer",
    "CloudFront-Is-Mobile-Viewer",
    "CloudFront-Is-Tablet-Viewer",
    "x-strapi-signature"
  ]

  # Optional: Add cache behaviors for static assets
  # cache_behaviors = var.cloudfront_cache_behaviors

  # Optional: Basic authentication
  enable_default_auth = var.cloudfront_client_enable_auth
  basic_auth_username = var.cloudfront_client_auth_username
  basic_auth_password = var.cloudfront_client_auth_password

  # Cost optimization
  price_class = "PriceClass_200"

  tags = local.tags
}
```

## variables.tf

```terraform
variable "cloudfront_client_enable_auth" {
  description = "Enable basic authentication for CloudFront client distribution"
  type        = bool
}

variable "cloudfront_client_auth_username" {
  description = "Username for CloudFront client basic authentication"
  type        = string
}

variable "cloudfront_client_auth_password" {
  description = "Password for CloudFront client basic authentication"
  type        = string
  sensitive   = true
}
```

## terraform.tfvars

```hcl
cloudfront_client_enable_auth   = true
cloudfront_client_auth_username = "fid-client"
cloudfront_client_auth_password = ""
```

## Outputs

```terraform

```
