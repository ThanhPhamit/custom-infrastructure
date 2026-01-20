# Network Module - Sample Usage

## main.tf

```terraform
module "acm" {
  source = "../modules/acm"

  domain       = var.app_cert_dns_domain # cert for zone root domain
  app_dns_zone = var.app_dns_zone

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  tags = local.tags
}
```

## variables.tf

```terraform
variable "app_cert_dns_domain" {
  description = "The domain name for the ACM certificate"
  type        = string
}
variable "app_dns_zone" {
  description = "The domain name for the Route 53 DNS zone"
  type        = string
}
```

## terraform.tfvars

```hcl
app_cert_dns_domain = "staging.focusidesign.com"
app_dns_zone        = "focusidesign.com"
```

## Outputs

```terraform

```
