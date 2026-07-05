################################################################################
# General
################################################################################

variable "app_name" {
  description = "Application/name prefix applied to every resource name and the Name tag."
  type        = string

  validation {
    condition     = length(trimspace(var.app_name)) > 0
    error_message = "app_name must be a non-empty string."
  }
}

variable "tags" {
  description = "Additional tags merged onto every taggable resource created by this module."
  type        = map(string)
  default     = {}
}

################################################################################
# Placement
################################################################################

variable "vpc_id" {
  description = "VPC the outbound endpoint, its security group, and the rule association live in."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g. vpc-0123456789abcdef0)."
  }
}

variable "subnet_ids" {
  description = "Subnets for the outbound ENIs — one ENI per subnet; AWS requires at least two."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Route 53 Resolver endpoints require at least two subnets."
  }
}

variable "ip_addresses" {
  description = "Optional fixed private IPs for the outbound ENIs, matched positionally to subnet_ids. Pin these so the on-prem firewall can allow-list stable source IPs. Missing entries are auto-assigned."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.ip_addresses : can(cidrhost("${ip}/32", 0))])
    error_message = "Every entry in ip_addresses must be a valid dotted-quad IPv4 address (e.g. 192.168.0.11)."
  }
}

################################################################################
# Forwarding
################################################################################

variable "forward_domain" {
  description = "Domain whose queries are forwarded to the on-prem DNS (e.g. \"onprem.lab\"). Avoid \".local\" — reserved for mDNS (RFC 6762)."
  type        = string

  validation {
    condition     = length(trimspace(var.forward_domain)) > 0 && !endswith(var.forward_domain, ".local")
    error_message = "forward_domain must be non-empty and must not end in .local (reserved for mDNS, RFC 6762)."
  }
}

variable "target_dns_ips" {
  description = "On-prem DNS server IPs that queries for forward_domain are sent to (e.g. the dnsmasq on the VPS LAN)."
  type        = list(string)

  validation {
    condition     = length(var.target_dns_ips) >= 1 && alltrue([for ip in var.target_dns_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "target_dns_ips must contain at least one valid IPv4 address."
  }
}

variable "target_dns_port" {
  description = "Port the on-prem DNS server listens on."
  type        = number
  default     = 53
}
