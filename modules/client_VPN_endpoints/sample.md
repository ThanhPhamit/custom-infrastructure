# Network Module - Sample Usage

## main.tf

```terraform
module "client_vpn" {
  source = "../modules/client_VPN_endpoints"

  organization_name = var.organization_name
  app_name          = "${var.environment}-${var.app_name}"
  vpn_domain        = var.vpn_domain

  vpc_id     = var.vpc_id
  subnet_ids = [for subnet in data.aws_subnet.public_subnets : subnet.id]

  client_cidr_block = var.client_cidr_block

  allowed_cidr_blocks = var.vpn_allowed_cidr_blocks

  split_tunnel         = false
  private_subnet_cidrs = local.private_subnet_cidrs

  enable_vpn_associations = var.enable_vpn_associations

  tags = local.tags
}
```

## variables.tf

```terraform
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the Client VPN endpoint"
  type        = list(string)
}
variable "client_cidr_block" {
  description = "CIDR block for VPN clients (should not overlap with VPC)"
  type        = string
  default     = "10.0.0.0/16"
}
variable "organization_name" {
  description = "Organization name for certificate subjects"
  type        = string
  default     = "Internal Organization"
}
variable "vpn_domain" {
  description = "Domain name for the VPN server certificate"
  type        = string
}
variable "vpn_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the VPN"
  type        = list(string)
}
variable "enable_vpn_associations" {
  description = "Enable VPN network associations (set to false to save costs)"
  type        = bool
}
```

## terraform.tfvars

```hcl
public_subnet_ids       = ["subnet-0e930e8326b8058b8"]
client_cidr_block       = "172.24.0.0/22"
organization_name       = "welfan"
vpn_domain              = "vpn.welfan.internal"
vpn_allowed_cidr_blocks = ["115.78.131.125/32"]
enable_vpn_associations = true
```

## Outputs

```terraform

```
