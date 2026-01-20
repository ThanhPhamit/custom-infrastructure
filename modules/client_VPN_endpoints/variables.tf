variable "organization_name" {
  description = "Organization name for certificate subjects"
  type        = string
  default     = "Internal Organization"
}

variable "app_name" {
  description = "Application name for resource naming"
  type        = string
}

variable "vpn_domain" {
  description = "Domain name for the VPN server certificate"
  type        = string
}

variable "certificate_validity_period_hours" {
  description = "Validity period for client certificates in hours"
  type        = number
  default     = 8760 # 1 year
}

variable "vpc_id" {
  description = "VPC ID where the Client VPN endpoint will be created"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the VPN"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "client_cidr_block" {
  description = "CIDR block for VPN clients (should not overlap with VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "split_tunnel" {
  description = "Enable split tunneling for the VPN"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "List of subnet IDs to associate with the Client VPN endpoint"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_vpn_associations" {
  description = "Enable VPN network associations (set to false to save costs)"
  type        = bool
}
