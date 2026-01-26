# AWS S3 API Assets Terraform Module

Terraform module which creates an S3 bucket for API assets with CloudFront OAI integration.

## Features

This module supports creating:

- **S3 Bucket** - Private bucket for static assets
- **Bucket Policy** - CloudFront OAI access policy
- **CORS Configuration** - Cross-origin request support

## Usage

### Example 1: Basic API Assets Bucket

```terraform
module "s3_api_assets" {
  source = "../../modules/s3_api_assets"

  app_name                       = "${var.environment}-${var.app_name}"
  api_domain                     = var.api_domain
  frontend_agent_domain          = var.frontend_agent_domain
  frontend_jobseeker_domain      = var.frontend_jobseeker_domain
  origin_access_identity_iam_arn = module.cloudfront.origin_access_identity_iam_arn

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Using with CloudFront

```terraform
module "cloudfront" {
  source = "../../modules/cloudfront"

  app_name        = "${var.environment}-${var.app_name}"
  alb_domain_name = module.alb.domain
  # ... other configuration ...
}

module "s3_api_assets" {
  source = "../../modules/s3_api_assets"

  app_name                       = "${var.environment}-${var.app_name}"
  api_domain                     = "api.example.com"
  frontend_agent_domain          = "agent.example.com"
  frontend_jobseeker_domain      = "www.example.com"
  origin_access_identity_iam_arn = module.cloudfront.origin_access_identity_iam_arn
}
```

## Inputs

| Name                           | Description                        | Type     | Required |
| ------------------------------ | ---------------------------------- | -------- | :------: |
| app_name                       | Application name for bucket naming | `string` |   yes    |
| api_domain                     | API domain for CORS                | `string` |   yes    |
| frontend_agent_domain          | Agent frontend domain for CORS     | `string` |   yes    |
| frontend_jobseeker_domain      | Jobseeker frontend domain for CORS | `string` |   yes    |
| origin_access_identity_iam_arn | CloudFront OAI IAM ARN             | `string` |   yes    |

## Outputs

| Name                        | Description          |
| --------------------------- | -------------------- |
| bucket_name                 | S3 bucket name       |
| bucket_regional_domain_name | Regional domain name |
| bucket_id                   | S3 bucket ID         |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
