variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "nlb_domain" {
  description = "Domain name for the NLB"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for TLS termination"
  type        = string
  default     = ""
}

variable "route_53_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where the NLB will be created"
  type        = string
}

variable "restricted_source_ips" {
  description = "List of CIDR blocks to allow for the security group ingress rules"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs for the NLB"
  type        = list(string)
}

variable "nlb_internal" {
  type        = bool
  description = "Whether the NLB is internal or not"
  default     = false
}

variable "enable_security_groups" {
  type        = bool
  description = "Whether to enable security groups for the NLB (requires ENI mode)"
  default     = false
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for the NLB"
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  description = "Enable cross-zone load balancing for the NLB"
  default     = false
}

variable "enable_tls_termination" {
  type        = bool
  description = "Enable TLS termination at the NLB level"
  default     = false
}

variable "create_route53_record" {
  type        = bool
  description = "Whether to create a Route 53 record"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "use_fixed_ips" {
  type        = bool
  description = "Whether to use fixed IP addresses for the NLB"
  default     = false
}

variable "subnet_mappings" {
  type = list(object({
    subnet_id            = string
    allocation_id        = optional(string) # Elastic IP allocation ID for internet-facing NLBs
    private_ipv4_address = optional(string) # Fixed private IP for internal NLBs
  }))
  description = "Subnet mappings with optional fixed IP addresses"
  default     = []
}
