# Network Module - Sample Usage

## main.tf
```terraform
module "network" {
  source = "../../modules/network"

  app_name              = var.app_name
  aws_region            = var.region
  azs_name              = var.azs_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_ciders  = var.public_subnet_ciders
  private_subnet_ciders = var.private_subnet_ciders
}
```

## variables.tf
```terraform
variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "azs_name" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ciders" {
  type = list(string)
}

variable "private_subnet_ciders" {
  type = list(string)
}
```

## terraform.tfvars
```hcl
region                = "ap-northeast-1"
app_name              = "welfan-namecard-staging"
azs_name              = ["a", "c"]
vpc_cidr              = "10.22.0.0/16"
public_subnet_ciders  = ["10.22.0.0/23", "10.22.2.0/23"]
private_subnet_ciders = ["10.22.4.0/23", "10.22.6.0/23"]
```

## Outputs
```terraform
# Access outputs:
module.network.vpc_id
module.network.private_subnet_ids
module.network.public_subnet_ids
```
