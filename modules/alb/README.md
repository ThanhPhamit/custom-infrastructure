# AWS Application Load Balancer (ALB) Terraform Module

Terraform module which creates Application Load Balancer resources on AWS.

## Features

This module supports creating:

- **Application Load Balancer** - Internal or Internet-facing
- **Security Group** - With configurable ingress rules
- **HTTPS Listeners** - Production (443) and Test (10443) ports
- **HTTP Redirect** - Automatic HTTP to HTTPS redirect
- **Route53 DNS Record** - Optional A record for the ALB
- **CloudFront Integration** - Support for CloudFront prefix list

## Usage

### Example 1: Internal ALB (Private Services)

```terraform
module "alb_internal" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-api"
  vpc_id   = module.network.vpc_id

  restricted_source_ips = concat(
    [for subnet in data.aws_subnet.public_subnets : subnet.cidr_block],
    var.alb_restricted_source_ips
  )

  subnet_ids          = [for subnet in data.aws_subnet.private_subnets : subnet.id]
  alb_internal        = true
  route_53_zone_id    = data.aws_route53_zone.internal.id
  acm_certificate_arn = module.internal_acm.certificate_arn
  alb_domain          = var.alb_api_domain

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 2: Internet-Facing ALB (Public Services)

```terraform
module "alb_public" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-public"
  vpc_id   = module.network.vpc_id

  restricted_source_ips = ["0.0.0.0/0"]  # Allow all internet traffic

  subnet_ids          = [for subnet in data.aws_subnet.public_subnets : subnet.id]
  alb_internal        = false
  route_53_zone_id    = data.aws_route53_zone.public.id
  acm_certificate_arn = module.acm.certificate_arn
  alb_domain          = var.alb_public_domain

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: ALB with CloudFront (CDN)

```terraform
module "alb_with_cloudfront" {
  source = "../../modules/alb"

  app_name = "${var.environment}-${var.app_name}-cdn"
  vpc_id   = module.network.vpc_id

  # Only allow traffic from CloudFront
  restricted_source_ips        = []
  allow_cloudfront_prefix_list = true

  subnet_ids          = [for subnet in data.aws_subnet.public_subnets : subnet.id]
  alb_internal        = false
  acm_certificate_arn = module.acm.certificate_arn

  # Skip Route53 record - CloudFront will handle DNS
  # route_53_zone_id and alb_domain are optional when create_route53_record = false
  create_route53_record = false

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## ALB Placement Options

| Option                 | Description                             | Use Case                    |
| ---------------------- | --------------------------------------- | --------------------------- |
| `alb_internal = true`  | Internal ALB accessible only within VPC | Backend APIs, microservices |
| `alb_internal = false` | Internet-facing ALB publicly accessible | Public websites, APIs       |

## Security Configuration Options

| Option                                   | Description                                |
| ---------------------------------------- | ------------------------------------------ |
| `restricted_source_ips = ["0.0.0.0/0"]`  | Allow all internet traffic                 |
| `restricted_source_ips = ["10.0.0.0/8"]` | Allow only internal VPC traffic            |
| `allow_cloudfront_prefix_list = true`    | Allow traffic only from CloudFront         |
| `create_route53_record = false`          | Skip Route53 record (for CloudFront setup) |

## Listeners Created

| Port  | Protocol | Description             |
| ----- | -------- | ----------------------- |
| 443   | HTTPS    | Production traffic      |
| 10443 | HTTPS    | Test/staging traffic    |
| 80    | HTTP     | Redirect to HTTPS (301) |

## Inputs

| Name                         | Description                                | Type           | Default | Required                                |
| ---------------------------- | ------------------------------------------ | -------------- | ------- | --------------------------------------- |
| app_name                     | Name of the application                    | `string`       | n/a     | yes                                     |
| vpc_id                       | ID of the VPC where ALB will be created    | `string`       | n/a     | yes                                     |
| subnet_ids                   | List of subnet IDs for ALB deployment      | `list(string)` | n/a     | yes                                     |
| acm_certificate_arn          | ARN of ACM certificate for HTTPS listeners | `string`       | n/a     | yes                                     |
| route_53_zone_id             | Route 53 hosted zone ID for DNS records    | `string`       | `null`  | yes (when `create_route53_record=true`) |
| restricted_source_ips        | List of CIDR blocks allowed to access ALB  | `list(string)` | n/a     | yes                                     |
| alb_domain                   | Domain name for the ALB                    | `string`       | `null`  | yes (when `create_route53_record=true`) |
| alb_internal                 | Whether the ALB is internal                | `bool`         | `false` | no                                      |
| allow_cloudfront_prefix_list | Allow traffic from CloudFront prefix list  | `bool`         | `false` | no                                      |
| create_route53_record        | Whether to create Route 53 DNS record      | `bool`         | `true`  | no                                      |
| tags                         | Tags to apply to resources                 | `map(string)`  | `{}`    | no                                      |

> **Note:** When `create_route53_record = false` (e.g., using CloudFront), both `route_53_zone_id` and `alb_domain` become optional and can be omitted.

## Outputs

| Name                          | Description                           |
| ----------------------------- | ------------------------------------- |
| id                            | The ID of the ALB                     |
| domain                        | The DNS name of the ALB               |
| alb_arn_suffix                | The ARN suffix for CloudWatch metrics |
| alb_security_group_id         | Security group ID of the ALB          |
| lb_listener_http_arn          | ARN of the HTTP listener              |
| lb_listener_http_prod_arn     | ARN of the production HTTPS listener  |
| lb_listener_http_test_arn     | ARN of the test HTTPS listener        |
| lb_listener_http_redirect_arn | ARN of the HTTP redirect listener     |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
