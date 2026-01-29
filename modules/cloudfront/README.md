# AWS CloudFront Distribution Terraform Module

Terraform module which creates CloudFront distribution with ALB origin on AWS.

## Features

This module supports creating:

- **CloudFront Distribution** - CDN distribution with ALB origin
- **Cache Policy** - Custom caching configuration
- **Origin Request Policy** - Header forwarding configuration
- **Route53 DNS Record** - Custom domain alias
- **Lambda@Edge** - Optional basic authentication
- **CloudFront Function** - Lightweight edge functions

## Usage

### Example 1: Basic CloudFront with ALB Origin

```terraform
module "cloudfront" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-web"
  alb_domain_name = module.alb.domain

  # Custom domain configuration
  custom_domain       = "www.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Cache settings
  min_ttl     = 0
  default_ttl = 300    # 5 minutes
  max_ttl     = 86400  # 24 hours

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: CloudFront with Basic Authentication

```terraform
module "cloudfront" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-staging"
  alb_domain_name = module.alb.domain

  custom_domain       = "staging.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Enable basic authentication
  enable_default_auth = true
  basic_auth_username = var.cloudfront_auth_username
  basic_auth_password = var.cloudfront_auth_password

  # Cache settings
  min_ttl     = 0
  default_ttl = 300
  max_ttl     = 86400

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: CloudFront with Custom Cache Behaviors

```terraform
module "cloudfront" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-web"
  alb_domain_name = module.alb.domain

  custom_domain       = "www.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Default cache settings
  min_ttl     = 0
  default_ttl = 300
  max_ttl     = 86400

  # Custom headers to forward
  forwarded_headers = [
    "Host",
    "CloudFront-Forwarded-Proto",
    "CloudFront-Is-Desktop-Viewer",
    "CloudFront-Is-Mobile-Viewer",
    "CloudFront-Is-Tablet-Viewer"
  ]

  # Additional cache behaviors
  cache_behaviors = [
    {
      path_pattern    = "/api/*"
      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods  = ["GET", "HEAD"]
      cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
      enable_auth     = false
    },
    {
      path_pattern    = "/admin/*"
      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]
      enable_auth     = true  # Enable auth for admin paths
    }
  ]

  price_class = "PriceClass_200"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 4: CloudFront with Geographic Restrictions

```terraform
module "cloudfront" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-web"
  alb_domain_name = module.alb.domain

  custom_domain       = "www.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Geographic restrictions
  geo_restriction_type      = "whitelist"
  geo_restriction_locations = ["JP", "US", "GB"]

  price_class = "PriceClass_200"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## Price Class Options

| Price Class      | Edge Locations                                 | Cost    |
| ---------------- | ---------------------------------------------- | ------- |
| `PriceClass_100` | USA, Canada, Europe, Israel                    | Lowest  |
| `PriceClass_200` | PriceClass_100 + Asia (Japan, Singapore, etc.) | Medium  |
| `PriceClass_All` | All worldwide edge locations                   | Highest |

## AWS Managed Policies vs Custom Policies

This module supports both **AWS Managed Policies** and **Custom Policies**. For most use cases, **AWS Managed Policies are recommended** as they handle edge cases and restricted headers properly.

📚 **Official Documentation:**

- [Managed Cache Policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html)
- [Managed Origin Request Policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html)

### When to use Managed Policies

| Use Case                                         | Cache Policy       | Origin Request Policy       |
| ------------------------------------------------ | ------------------ | --------------------------- |
| **API Server (no cache, forward Authorization)** | `CachingDisabled`  | `AllViewerExceptHostHeader` |
| **Static Website**                               | `CachingOptimized` | `CORS-S3Origin`             |
| **Web App with dynamic content**                 | `CachingOptimized` | `AllViewer`                 |

### Managed Cache Policy IDs

| Policy Name                              | ID                                     | Description                                              |
| ---------------------------------------- | -------------------------------------- | -------------------------------------------------------- |
| `CachingDisabled`                        | `4135ea2d-6df8-44a3-9df3-4b5a84be39ad` | No caching, forward all query strings. **Use for APIs.** |
| `CachingOptimized`                       | `658327ea-f89d-4fab-a63d-7e88639e58f6` | Optimized for static content                             |
| `CachingOptimizedForUncompressedObjects` | `b2884449-e4de-46a7-ac36-70bc7f1ddd6d` | Large uncompressed files                                 |
| `Amplify`                                | `2e54312d-136d-493c-8eb9-b001f22f67d2` | AWS Amplify applications                                 |

### Managed Origin Request Policy IDs

| Policy Name                             | ID                                     | Description                                                                                 |
| --------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------- |
| `AllViewerExceptHostHeader`             | `b689b0a8-53d0-40ab-baf2-68738e2966ac` | Forwards all headers **including Authorization** (except Host). **Use for APIs with auth.** |
| `AllViewer`                             | `216adef6-5c7f-47e4-b989-5492eafa07d3` | Forwards all viewer headers                                                                 |
| `AllViewerAndCloudFrontHeaders-2022-06` | `33f36d7e-f396-46d9-90e0-52428a34d9dc` | All headers + CloudFront headers                                                            |
| `CORS-S3Origin`                         | `88a5eaf4-2fd4-4709-b370-b4c650ea3fcf` | CORS headers for S3 origin                                                                  |
| `CORS-CustomOrigin`                     | `59781a5b-3903-41f3-afcb-af62929ccde1` | CORS headers for custom origin                                                              |
| `UserAgentRefererHeaders`               | `acba4595-bd28-49b8-b9fe-13317c0390fa` | Only User-Agent and Referer                                                                 |

### Example: API Server with Authentication

```terraform
module "cloudfront_api" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-api"
  alb_domain_name = module.alb.domain

  custom_domain       = "api.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Use AWS Managed Policies (RECOMMENDED for APIs)
  cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
  origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader

  price_class = "PriceClass_200"
  tags        = local.tags
}
```

> ⚠️ **Important:** When using `cache_policy_id` and `origin_request_policy_id`, the module will skip creating custom policies and use the managed ones instead.

> ⚠️ **Warning:** `Authorization` header is a **restricted header** in CloudFront. You cannot add it to custom Origin Request Policies. Use managed policy `AllViewerExceptHostHeader` instead!

## Inputs

| Name                      | Description                                | Type           | Default            | Required |
| ------------------------- | ------------------------------------------ | -------------- | ------------------ | :------: |
| app_name                  | Application name for resource naming       | `string`       | n/a                |   yes    |
| alb_domain_name           | ALB DNS name (origin)                      | `string`       | n/a                |   yes    |
| custom_domain             | Custom domain for CloudFront               | `string`       | `""`               |    no    |
| acm_certificate_arn       | ACM certificate ARN (must be in us-east-1) | `string`       | `""`               |    no    |
| route_53_zone_id          | Route 53 hosted zone ID                    | `string`       | `""`               |    no    |
| forwarded_headers         | Headers to forward to origin               | `list(string)` | Default headers    |    no    |
| min_ttl                   | Minimum TTL for cache                      | `number`       | `0`                |    no    |
| default_ttl               | Default TTL for cache                      | `number`       | `300`              |    no    |
| max_ttl                   | Maximum TTL for cache                      | `number`       | `31536000`         |    no    |
| cache_behaviors           | Additional cache behaviors                 | `list(object)` | `[]`               |    no    |
| geo_restriction_type      | Geographic restriction type                | `string`       | `"none"`           |    no    |
| geo_restriction_locations | Country codes for restrictions             | `list(string)` | `[]`               |    no    |
| price_class               | CloudFront price class                     | `string`       | `"PriceClass_All"` |    no    |
| enable_logging            | Enable access logging                      | `bool`         | `false`            |    no    |
| enable_ipv6               | Enable IPv6 support                        | `bool`         | `true`             |    no    |
| enable_default_auth       | Enable basic authentication                | `bool`         | `false`            |    no    |
| basic_auth_username       | Username for basic auth                    | `string`       | `"admin"`          |    no    |
| basic_auth_password       | Password for basic auth                    | `string`       | `""`               |    no    |
| tags                      | Tags to apply to resources                 | `map(string)`  | `{}`               |    no    |

## Outputs

| Name                        | Description                                |
| --------------------------- | ------------------------------------------ |
| cloudfront_distribution_id  | ID of the CloudFront distribution          |
| cloudfront_distribution_arn | ARN of the CloudFront distribution         |
| cloudfront_domain_name      | Domain name of the CloudFront distribution |
| cloudfront_hosted_zone_id   | Hosted zone ID of CloudFront               |
| custom_domain               | Custom domain name (if configured)         |
| cloudfront_status           | Status of the CloudFront distribution      |
| cloudfront_function_arn     | ARN of the CloudFront Function             |
| access_urls                 | Map of available access URLs               |

## Important: Forwarded Headers Configuration

When using CloudFront with an API backend, you **must** configure `forwarded_headers` properly to ensure your application works correctly.

### For API Servers (NestJS, Express, etc.)

```terraform
forwarded_headers = [
  "Host",                           # Server knows which domain is being requested
  "Authorization",                  # JWT/Bearer token authentication (CRITICAL!)
  "CloudFront-Forwarded-Proto",     # Server knows HTTPS or HTTP
  "CloudFront-Is-Desktop-Viewer",   # Device detection
  "CloudFront-Is-Mobile-Viewer",    # Device detection
  "CloudFront-Is-Tablet-Viewer",    # Device detection
  "Origin",                         # CORS - which domain is making the request
  "Access-Control-Request-Headers", # CORS preflight requests
  "Access-Control-Request-Method",  # CORS preflight requests
]
```

### For Web Applications (Vue, React, Angular SSR)

```terraform
forwarded_headers = [
  "Host",
  "CloudFront-Forwarded-Proto",
  "CloudFront-Is-Desktop-Viewer",
  "CloudFront-Is-Mobile-Viewer",
  "CloudFront-Is-Tablet-Viewer",
]
```

### Header Reference

| Header                       | Purpose                                 | When to use                    |
| ---------------------------- | --------------------------------------- | ------------------------------ |
| `Host`                       | Server knows the domain being requested | Always                         |
| `Authorization`              | JWT/Bearer token authentication         | **API servers with auth**      |
| `CloudFront-Forwarded-Proto` | Server knows if HTTPS or HTTP           | Redirect logic, secure cookies |
| `CloudFront-Is-*-Viewer`     | Device type detection                   | Responsive logic on server     |
| `Origin`                     | CORS - origin domain of request         | API servers with CORS          |
| `Access-Control-Request-*`   | CORS preflight requests                 | API servers with CORS          |
| `x-strapi-signature`         | Strapi webhook verification             | Strapi CMS only                |

> ⚠️ **Warning:** Without `Authorization` header forwarding, your API authentication (JWT tokens) will NOT work through CloudFront!

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## Notes

- ACM certificate must be in `us-east-1` region for CloudFront
- Basic authentication uses CloudFront Functions (lighter than Lambda@Edge)
- Distribution deployment may take 15-30 minutes

## When to Use CloudFront

CloudFront is **NOT always necessary**. Consider your use case:

### ✅ **USE CloudFront when:**

| Scenario                                | Benefit                                            |
| --------------------------------------- | -------------------------------------------------- |
| **Users worldwide** (US, EU, Asia)      | AWS Private Backbone reduces latency significantly |
| **Static content** (S3, images, JS/CSS) | Caching at edge = faster + cheaper                 |
| **DDoS protection needed**              | AWS Shield Standard (free) included                |
| **WAF (Web Application Firewall)**      | Easy to attach                                     |
| **Basic auth for staging**              | CloudFront Functions for authentication            |

### ❌ **SKIP CloudFront when:**

| Scenario                                                             | Reason                                       |
| -------------------------------------------------------------------- | -------------------------------------------- |
| **Users only in same region as ALB** (e.g., Japan users + Tokyo ALB) | No latency benefit, just adds cost           |
| **API with no caching**                                              | CloudFront adds ~$8-10/month with no benefit |
| **Low budget staging**                                               | Direct ALB is simpler and cheaper            |

### 💰 **Cost Comparison (1000 users/day, ~100K requests/day):**

| Setup                            | Monthly Cost |
| -------------------------------- | ------------ |
| ALB only                         | ~$20         |
| ALB + CloudFront (API, no cache) | ~$28-30      |
| CloudFront + S3 (static)         | ~$3-6        |

### 🌏 **Latency Comparison:**

```
Users in JAPAN → Tokyo ALB:
  Without CloudFront: ~10-15ms ✅
  With CloudFront:    ~10-15ms ✅ (no difference)

Users in USA → Tokyo ALB:
  Without CloudFront: ~150-200ms (public internet, unstable)
  With CloudFront:    ~100-130ms ✅ (AWS backbone, stable)
```

### 📋 **Decision Guide:**

```
┌─────────────────────────────────────────┐
│         Where are your users?          │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
   Same region          Global
   (e.g., Japan)        (US, EU, Asia)
        │                   │
        ▼                   ▼
┌───────────────┐   ┌───────────────────┐
│ Static files? │   │ Use CloudFront ✅ │
└───────┬───────┘   │ - Caching benefit │
        │           │ - AWS backbone    │
   ┌────┴────┐      │ - DDoS protection │
   ▼         ▼      └───────────────────┘
  Yes       No (API)
   │         │
   ▼         ▼
┌────────┐ ┌─────────────────┐
│Use CF ✅│ │Skip CloudFront ❌│
│Caching │ │Use ALB directly │
└────────┘ │Cost saving      │
           └─────────────────┘
```

### Example: Japan-only API (No CloudFront)

```terraform
# Direct ALB without CloudFront - for Japan-only users
module "alb_server" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-server"
  vpc_id   = module.vpc.vpc_id

  # Allow from anywhere (or restrict to specific IPs)
  restricted_source_ips = ["0.0.0.0/0"]

  subnet_ids          = module.vpc.public_subnet_ids
  alb_internal        = false
  acm_certificate_arn = module.acm.certificate_arn

  # Create Route53 record directly for ALB
  create_route53_record = true
  route_53_zone_id      = data.aws_route53_zone.public.id
  alb_domain            = "api.example.com"

  tags = local.tags
}
```

### Example: Global API (With CloudFront)

```terraform
# ALB behind CloudFront - for global users
module "alb_server" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-server-cdn"
  vpc_id   = module.vpc.vpc_id

  # Only allow traffic from CloudFront
  restricted_source_ips        = []
  allow_cloudfront_prefix_list = true

  subnet_ids          = module.vpc.public_subnet_ids
  alb_internal        = false
  acm_certificate_arn = module.acm.certificate_arn

  # Skip Route53 - CloudFront will handle DNS
  create_route53_record = false

  tags = local.tags
}

module "cloudfront_api" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}-api"
  alb_domain_name = module.alb_server.domain

  custom_domain       = "api.example.com"
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id

  # Use AWS Managed Policies for API
  cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
  origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader

  price_class = "PriceClass_200"
  tags        = local.tags
}
```

## License

Apache 2 Licensed. See LICENSE for full details.
