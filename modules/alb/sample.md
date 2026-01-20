# Application Load Balancer (ALB) Module - Sample Usage

## Example 1: Internal ALB (Private Services)

```terraform
module "alb_nuxt" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-nuxt"
  vpc_id   = data.aws_vpc.this.id

  restricted_source_ips = concat(
    [for subnet in data.aws_subnet.public_subnets : subnet.cidr_block],
    var.alb_restricted_source_ips
  )

  subnet_ids          = [for subnet in data.aws_subnet.private_subnets : subnet.id]
  alb_internal        = true
  route_53_zone_id    = data.aws_route53_zone.this.id
  acm_certificate_arn = module.internal_acm.certificate_arn
  alb_domain          = var.alb_nuxt_domain

  tags = local.tags
}
```

---

## Example 2: Internet-Facing ALB (Public Services)

```terraform
module "alb_public" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-public"
  vpc_id   = data.aws_vpc.this.id

  restricted_source_ips = ["0.0.0.0/0"]  # Allow all internet traffic

  subnet_ids          = [for subnet in data.aws_subnet.public_subnets : subnet.id]
  alb_internal        = false
  route_53_zone_id    = data.aws_route53_zone.public.id
  acm_certificate_arn = module.public_acm.certificate_arn
  alb_domain          = var.alb_public_domain

  tags = local.tags
}
```

---

## Example 3: ALB with CloudFront (CDN)

```terraform
module "alb_with_cloudfront" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-cdn"
  vpc_id   = data.aws_vpc.this.id

  # Only allow traffic from CloudFront
  restricted_source_ips        = []
  allow_cloudfront_prefix_list = true

  subnet_ids          = [for subnet in data.aws_subnet.public_subnets : subnet.id]
  alb_internal        = false
  acm_certificate_arn = module.public_acm.certificate_arn
  
  # Skip Route53 record - CloudFront will handle DNS
  create_route53_record = false
  route_53_zone_id      = data.aws_route53_zone.public.id

  tags = local.tags
}
```

---

## variables.tf

```terraform
variable "environment" {
  type        = string
  description = "Environment name (staging, production, etc.)"
}

variable "app_name" {
  type        = string
  description = "Application name"
}

variable "alb_restricted_source_ips" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
}

variable "alb_nuxt_domain" {
  description = "Domain name for the internal Nuxt ALB"
  type        = string
}

variable "alb_public_domain" {
  description = "Domain name for the public ALB"
  type        = string
}
```

---

## terraform.tfvars

```hcl
environment = "staging"
app_name    = "welfan-namecard"

# Internal ALB
alb_nuxt_domain = "staging.welfan.internal"
alb_restricted_source_ips = [
  "192.168.0.0/16",  # WCS systems
  "10.0.0.0/8"       # Internal VPC
]

# Public ALB
alb_public_domain = "api.welfan.com"
```

---

## Module Configuration Options

| Option | Description |
|--------|-------------|
| `alb_internal = true` | Internal ALB accessible only within VPC |
| `alb_internal = false` | Internet-facing ALB publicly accessible |
| `allow_cloudfront_prefix_list = true` | Allow traffic only from CloudFront |
| `create_route53_record = false` | Skip Route53 record (for CloudFront setup) |

---

## Listeners Created

| Port | Protocol | Description |
|------|----------|-------------|
| 443 | HTTPS | Production traffic |
| 10443 | HTTPS | Test/staging traffic |
| 80 | HTTP | Redirect to HTTPS (301) |

---

## Outputs

```terraform
module.alb_nuxt.id                         # ALB ID
module.alb_nuxt.domain                     # AWS DNS name
module.alb_nuxt.alb_arn_suffix             # ARN suffix for CloudWatch
module.alb_nuxt.alb_security_group_id      # Security group ID
module.alb_nuxt.lb_listener_http_prod_arn  # HTTPS 443 listener ARN
module.alb_nuxt.lb_listener_http_test_arn  # HTTPS 10443 listener ARN
module.alb_nuxt.lb_listener_http_redirect_arn  # HTTP 80 redirect listener ARN
```
