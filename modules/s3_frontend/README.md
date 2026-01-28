# AWS S3 Frontend Hosting Terraform Module

Terraform module which creates S3 bucket with CloudFront distribution for hosting static frontend applications (React, Vue, Angular, Next.js static export, etc.).

## Features

This module supports creating:

- **S3 Bucket** - Private bucket with versioning enabled
- **CloudFront Distribution** - Global CDN with HTTPS, supports multiple subdomains
- **Origin Access Control (OAC)** - Secure S3 access (recommended over OAI)
- **SPA Router Function** - CloudFront Function for subdomain-based Vue/React apps
- **Basic Authentication** - Optional CloudFront Function for staging protection
- **SPA Support** - Client-side routing support (403/404 → index.html)
- **Route53 DNS** - Automatic DNS record creation for all domains
- **Secrets Manager** - Secure basic auth credential storage

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Route53 DNS                               │
│  patient.example.com  ──┐                                   │
│  clinic.example.com   ──┼──→ CloudFront Distribution        │
│  admin.example.com    ──┘                                   │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│           CloudFront Distribution (1 distribution)          │
│  - aliases: [patient.*, clinic.*, admin.*]                  │
│  - CloudFront Function: SPA Router + Basic Auth             │
│  - All routes → index.html (client-side routing)            │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              S3 Bucket (1 bucket, same content)              │
│  /index.html ← Vue/React app detects subdomain client-side  │
│  /assets/*                                                   │
└──────────────────────────────────────────────────────────────┘
```

## Usage

### Example 1: Multi-Subdomain SPA (Vue/React with role detection)

```terraform
module "frontend" {
  source = "../../modules/s3_frontend"

  app_name = "${var.environment}-${var.app_name}"

  # Multiple subdomains - all served from same S3 bucket
  domains = [
    "patient.example.com",  # Patient portal
    "clinic.example.com",   # Clinic dashboard
    "admin.example.com"     # Admin panel
  ]

  acm_certificate_arn = module.acm_virginia.certificate_arn  # Must be us-east-1
  route_53_zone_id    = data.aws_route53_zone.main.zone_id

  # Enable SPA router for subdomain-based apps
  enable_spa_router = true

  # Enable basic auth for staging
  create_cloudfront_function = true
  basic_auth_password        = var.staging_password

  spa_mode            = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"

  tags = local.tags
}
```

### Example 2: Production (No Basic Auth)

```terraform
module "frontend" {
  source = "../../modules/s3_frontend"

  app_name            = "${var.environment}-${var.app_name}"
  domains             = ["www.example.com"]
  acm_certificate_arn = module.acm_virginia.certificate_arn
  route_53_zone_id    = data.aws_route53_zone.main.zone_id

  # Disable basic auth for production
  create_cloudfront_function = false
  enable_spa_router          = true

  spa_mode            = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: Static Website (Non-SPA)

```terraform
module "docs_site" {
  source = "../../modules/s3_frontend"

  app_name            = "${var.environment}-docs"
  domains             = ["docs.example.com"]
  acm_certificate_arn = module.acm_virginia.certificate_arn
  route_53_zone_id    = data.aws_route53_zone.main.zone_id

  create_cloudfront_function = false
  enable_spa_router          = false

  # Disable SPA mode for traditional static sites
  spa_mode            = false
  default_root_object = "index.html"

  price_class = "PriceClass_100"  # US/Europe only

  tags = local.tags
}
```

## Deploying Frontend Files

After creating the infrastructure, deploy your frontend files:

```bash
# Build your frontend
npm run build

# Sync to S3 (React/Vite)
aws s3 sync ./dist s3://BUCKET_NAME --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

### GitHub Actions Deployment Example

```yaml
- name: Deploy to S3
  run: |
    aws s3 sync ./dist s3://${{ secrets.S3_BUCKET }} --delete
    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
      --paths "/*"
```

## Price Class Options

| Price Class    | Regions                       | Cost    |
| -------------- | ----------------------------- | ------- |
| PriceClass_All | All edge locations            | Highest |
| PriceClass_200 | US, Europe, Asia, Middle East | Medium  |
| PriceClass_100 | US, Europe only               | Lowest  |

For Japan-focused applications, use `PriceClass_200`.

## SPA vs Static Site

| Feature             | SPA Mode (`spa_mode = true`) | Static Site (`spa_mode = false`) |
| ------------------- | ---------------------------- | -------------------------------- |
| 403/404 handling    | Redirect to index.html       | Show error page                  |
| Client-side routing | ✅ Supported                 | ❌ Not supported                 |
| Use case            | React, Vue, Angular          | Documentation, blogs             |

## Inputs

| Name                       | Description                                     | Type           | Default            | Required |
| -------------------------- | ----------------------------------------------- | -------------- | ------------------ | :------: |
| app_name                   | Application name for resource naming            | `string`       | n/a                |   yes    |
| domains                    | List of custom domain names (supports multiple) | `list(string)` | n/a                |   yes    |
| acm_certificate_arn        | ACM certificate ARN (must be in us-east-1)      | `string`       | n/a                |   yes    |
| route_53_zone_id           | Route53 hosted zone ID                          | `string`       | n/a                |   yes    |
| enable_spa_router          | Enable SPA router CloudFront Function           | `bool`         | `true`             |    no    |
| create_cloudfront_function | Enable basic auth in CloudFront function        | `bool`         | `true`             |    no    |
| basic_auth_password        | Password for basic auth (username = app_name)   | `string`       | `""`               |    no    |
| spa_mode                   | Enable SPA mode (403/404 → index.html)          | `bool`         | `true`             |    no    |
| default_root_object        | Default root object (index file)                | `string`       | `"index.html"`     |    no    |
| price_class                | CloudFront price class                          | `string`       | `"PriceClass_All"` |    no    |
| tags                       | Tags to apply to resources                      | `map(string)`  | `{}`               |    no    |

## Outputs

| Name                        | Description                                         |
| --------------------------- | --------------------------------------------------- |
| bucket_name                 | S3 bucket name (for aws s3 sync)                    |
| bucket_id                   | S3 bucket ID                                        |
| bucket_arn                  | S3 bucket ARN                                       |
| bucket_regional_domain_name | S3 bucket regional domain name                      |
| cloudfront_distribution_id  | CloudFront distribution ID (for cache invalidation) |
| cloudfront_distribution_arn | CloudFront distribution ARN                         |
| cloudfront_domain_name      | CloudFront distribution domain name                 |
| website_urls                | List of website URLs                                |
| domains                     | List of configured domains                          |
| basic_auth_secret_arn       | Secrets Manager ARN for basic auth credentials      |

## Basic Auth Credentials

When basic auth is enabled:

- **Username**: Same as `app_name`
- **Password**: Value of `basic_auth_password`
- **Credentials stored in**: AWS Secrets Manager

To retrieve credentials:

```bash
aws secretsmanager get-secret-value \
  --secret-id "app-name-CDN-basic-auth" \
  --query SecretString --output text | jq
```

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 1.4.0  |
| aws       | >= 5.86.1 |
| random    | >= 3.6.3  |

## Notes

1. **ACM Certificate**: Must be created in `us-east-1` region for CloudFront
2. **DNS Propagation**: May take a few minutes after creation
3. **Cache Invalidation**: Required after each deployment to see changes immediately

## License

Apache 2 Licensed. See LICENSE for full details.
