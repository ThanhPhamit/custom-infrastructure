################################################################################
# General
################################################################################

variable "app_name" {
  description = "Application/name prefix applied to every resource name and the Name tag (e.g. \"s2s-vpn-lab\")."
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
# Networking
################################################################################

variable "vpc_id" {
  description = "ID of the VPC the Route 53 Resolver inbound endpoint and its security group live in (and the VPC the query-log config associates with)."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g. vpc-0123456789abcdef0)."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs to place the resolver ENIs in — one inbound endpoint ENI (ip_address block) is created per subnet. AWS requires at least two for availability."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least 2 subnet IDs (Route 53 Resolver endpoints require a minimum of two ENIs)."
  }

  validation {
    condition     = alltrue([for s in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", s))])
    error_message = "Every entry in subnet_ids must be a valid subnet ID (e.g. subnet-0123456789abcdef0)."
  }
}

variable "allowed_cidr_blocks" {
  description = "Source CIDR blocks permitted to send DNS queries (UDP/TCP 53) to the resolver endpoint — typically the on-prem network CIDR(s) reachable over the Site-to-Site VPN."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "allowed_cidr_blocks must contain at least one CIDR block."
  }

  validation {
    condition     = alltrue([for c in var.allowed_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "Every entry in allowed_cidr_blocks must be a valid IPv4/IPv6 CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC — used as the egress destination for the resolver ENIs so they can reach the native VPC resolver / private zones (DNS on UDP/TCP 53)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 192.168.0.0/22)."
  }
}

variable "ip_addresses" {
  description = "Optional fixed private IPs to assign to the resolver ENIs, matched positionally to subnet_ids. If shorter than subnet_ids (or empty), the remaining ENIs get auto-assigned IPs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.ip_addresses : can(cidrhost("${ip}/32", 0))])
    error_message = "Every entry in ip_addresses must be a valid dotted-quad IPv4 address (e.g. 192.168.0.10)."
  }
}

################################################################################
# Query logging
################################################################################

variable "enable_query_logging" {
  description = "Whether to create a Route 53 Resolver query-log config + CloudWatch log group and associate it with the VPC."
  type        = bool
  default     = true
}

variable "query_log_retention_days" {
  description = "Retention period (in days) for the resolver query-log CloudWatch log group. Only used when enable_query_logging is true."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.query_log_retention_days
    )
    error_message = "query_log_retention_days must be a value supported by CloudWatch Logs (0 for never expire, or 1, 3, 5, 7, 14, 30, 60, 90, ... 3653)."
  }
}

variable "log_group_kms_key_arn" {
  description = "KMS key ARN used to encrypt the resolver query-log CloudWatch log group (key policy must grant logs.<region>.amazonaws.com). null uses the CloudWatch Logs default encryption."
  type        = string
  default     = null
}
