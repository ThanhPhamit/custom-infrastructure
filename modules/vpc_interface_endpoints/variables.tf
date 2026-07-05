variable "app_name" {
  description = "Application/environment name used to prefix and tag all resources (e.g. \"s2s-vpn-lab\")."
  type        = string

  validation {
    condition     = length(trimspace(var.app_name)) > 0
    error_message = "app_name must not be empty."
  }
}

variable "vpc_id" {
  description = "ID of the VPC in which the interface endpoints and their shared security group are created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g. \"vpc-0123456789abcdef0\")."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs in which to place endpoint ENIs. One ENI is created per subnet per service; use private subnets across the AZs you want reachable."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "subnet_ids must contain at least one subnet ID."
  }
}

variable "service_names" {
  description = "Short AWS service names for the interface endpoints (e.g. [\"sts\", \"secretsmanager\"]). Each is expanded to \"com.amazonaws.<region>.<name>\"."
  type        = list(string)

  validation {
    condition     = length(var.service_names) >= 1
    error_message = "service_names must contain at least one short service name."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the endpoints on TCP 443 (e.g. the on-prem and/or VPC CIDRs that consume the endpoints over the VPN). May be empty when allowed_security_group_ids supplies the sources instead."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "Each entry in allowed_cidr_blocks must be a valid CIDR block (e.g. \"192.168.0.0/22\")."
  }

  validation {
    condition     = length(var.allowed_cidr_blocks) + length(var.allowed_security_group_ids) >= 1
    error_message = "Provide at least one ingress source: allowed_cidr_blocks and/or allowed_security_group_ids."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups permitted to reach the endpoints on TCP 443, keyed by a STATIC label (e.g. { ec2-initiator = module.ec2.security_group_id }). Map keys must be plan-time constants because they drive for_each; values may be unknown until apply."
  type        = map(string)
  default     = {}
}

variable "private_dns_enabled" {
  description = "Whether to associate a private hosted zone so the service's default public DNS name resolves to the endpoint ENIs within the VPC."
  type        = bool
  default     = true
}

variable "endpoint_policies" {
  description = "Optional least-privilege endpoint policy JSON keyed by short service name (e.g. { sts = data.aws_iam_policy_document.sts.json }). A service absent from the map keeps the default full-access endpoint policy. Use this to constrain what the endpoint allows even if the SG is misconfigured or a credential leaks."
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region used to build endpoint service names. When null, the provider's current region (data.aws_region.current.region) is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged onto all resources created by this module."
  type        = map(string)
  default     = {}
}
