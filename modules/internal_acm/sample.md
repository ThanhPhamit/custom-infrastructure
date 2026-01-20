# Network Module - Sample Usage

## main.tf

```terraform
module "internal_acm" {
  source = "../modules/internal_acm"

  domain            = var.app_cert_dns_domain # Base domain (staging.welfan.internal)
  app_dns_zone      = var.app_dns_zone        # DNS zone name
  organization_name = "Staging Welfan Internal Organization"
  cert_output_path  = "${path.root}/certificates"

  # Optional: Customize certificate validity periods
  ca_validity_days     = 3650 # 10 years
  server_validity_days = 365  # 1 year

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
app_cert_dns_domain = "staging.welfan.internal"
app_dns_zone        = "welfan.internal"
```

## Outputs

```terraform

```
