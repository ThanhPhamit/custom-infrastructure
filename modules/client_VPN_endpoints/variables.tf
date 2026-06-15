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

variable "split_tunnel_destination_cidrs" {
  description = <<-EOT
    Extra (non-VPC) CIDRs that VPN clients are allowed to reach — each one is
    both authorized and routed. VPC CIDRs are handled separately via
    private_subnet_cidrs (auto-routed by the subnet association). Internet
    traffic and any on-prem range NOT listed here (e.g. the customer production
    network) are intentionally unreachable from the VPN.
    Example: ["192.168.0.0/24", "169.254.169.253/32"]  # on-prem DB + DNS resolver
  EOT
  type        = list(string)
  default     = []
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
