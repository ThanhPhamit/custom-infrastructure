# AWS ACM Certificate Terraform Module

Terraform module which creates and validates ACM certificates on AWS with automatic Route53 DNS validation.

## Features

This module supports creating:

- **ACM Certificate** - SSL/TLS certificate in the specified region
- **ACM Certificate (Virginia)** - Additional certificate in us-east-1 for CloudFront
- **Route53 DNS Validation** - Automatic DNS validation records
- **Wildcard Support** - Supports wildcard certificates (\*.domain.com)

## Usage

### Basic Example

```terraform
module "acm" {
  source = "../../modules/acm"

  domain       = "example.com"
  app_dns_zone = "example.com"

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Wildcard Certificate Example

```terraform
module "acm" {
  source = "../../modules/acm"

  domain       = "*.staging.example.com"
  app_dns_zone = "example.com"

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Subdomain Certificate Example

```terraform
module "acm" {
  source = "../../modules/acm"

  domain       = "api.staging.example.com"
  app_dns_zone = "example.com"

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

## Provider Configuration

This module requires two AWS providers:

```terraform
provider "aws" {
  region = "ap-northeast-1"  # Your primary region
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"  # Required for CloudFront certificates
}
```

## Inputs

| Name         | Description                                 | Type          | Default | Required |
| ------------ | ------------------------------------------- | ------------- | ------- | :------: |
| domain       | Domain name for the ACM certificate         | `string`      | n/a     |   yes    |
| app_dns_zone | Route53 hosted zone name for DNS validation | `string`      | n/a     |   yes    |
| tags         | Tags to apply to resources                  | `map(string)` | `{}`    |    no    |

## Outputs

| Name                     | Description                                    |
| ------------------------ | ---------------------------------------------- |
| certificate_id           | The ID of the ACM certificate                  |
| certificate_arn          | The ARN of the ACM certificate                 |
| virginia_certificate_arn | The ARN of the certificate in us-east-1 region |

## Use Cases

| Use Case                    | Configuration                    |
| --------------------------- | -------------------------------- |
| ALB/NLB in primary region   | Use `certificate_arn`            |
| CloudFront distribution     | Use `virginia_certificate_arn`   |
| Wildcard for all subdomains | Set `domain = "*.example.com"`   |
| Specific subdomain          | Set `domain = "api.example.com"` |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## Notes

- The Virginia certificate is required for CloudFront distributions
- DNS validation may take a few minutes to complete
- Ensure the Route53 hosted zone exists before creating the certificate

## License

Apache 2 Licensed. See LICENSE for full details.
