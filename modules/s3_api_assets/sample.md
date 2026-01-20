# Network Module - Sample Usage

## main.tf

```terraform
module "s3_api_assets" {
  source = "./s3_api_assets"

  app_name                       = var.app_name
  api_domain                     = var.api_domain
  frontend_agent_domain          = var.frontend_agent_domain
  frontend_jobseeker_domain      = var.frontend_jobseeker_domain
  origin_access_identity_iam_arn = module.cloudfront.origin_access_identity_iam_arn
}

```

## variables.tf

```terraform
variable "api_domain" {
  type    = string
  default = "api.staging.customer.edoa.co.jp"
}

variable "frontend_agent_domain" {
  type    = string
  default = "agent.staging.customer.edoa.co.jp"
}

variable "frontend_jobseeker_domain" {
  type    = string
  default = "staging.customer.edoa.co.jp"
}
```

## terraform.tfvars

```hcl

```

## Outputs

```terraform

```
