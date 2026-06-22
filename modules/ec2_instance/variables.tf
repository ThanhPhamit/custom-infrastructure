# =============================================================================
# ec2_instance — a single, reusable EC2 instance with its own security group,
# optional Elastic IP, and optional extra EBS data volume.
#
# Why this exists: the library's `bastion_host` module is bastion-only — its SG
# opens port 22 only and it attaches an instance profile solely for SSM. This
# module fixes both gaps: caller-supplied `ingress_rules` (any ports, CIDR or
# source-SG) and a caller-supplied `iam_instance_profile`. IMDSv2 is enforced.
# =============================================================================

variable "app_name" {
  description = "Full resource name for this instance (used as the Name tag and naming prefix), e.g. tokyo-staging-hinerism-web."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "ami_id" {
  description = "AMI ID to launch (caller looks it up, e.g. via data.aws_ami for Ubuntu 20.04)."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI id (ami-xxxxxxxx)."
  }
}

variable "instance_type" {
  description = "EC2 instance type (e.g. t3.medium)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance's security group is created."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to place the instance in. Its AZ also hosts the optional data volume."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH. null = no key (e.g. SSM-only access)."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "Assign an auto-public IP at launch. Prefer create_eip for a stable address; set false when using a private subnet."
  type        = bool
  default     = false
}

variable "create_eip" {
  description = "Create and attach an Elastic IP (stable public address for DNS/TLS)."
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "Name of an IAM instance profile to attach (grants the app/host its AWS access via IMDSv2). null = none."
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = <<-EOT
    Inbound rules for the instance's security group. Each rule allows EITHER a list
    of CIDRs OR a source security-group id (set one, leave the other empty/null).
  EOT
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = optional(string, "tcp")
    cidr_blocks              = optional(list(string), [])
    source_security_group_id = optional(string, null)
  }))
  default = []
}

variable "egress_cidr_blocks" {
  description = "CIDRs for the default all-protocol egress. Used only when egress_rules is empty."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "egress_rules" {
  description = <<-EOT
    Port-restricted egress rules. When non-empty, these REPLACE the default
    all-protocol egress — use to lock outbound to only what the box needs
    (e.g. a DB box: 80/443 for apt + AWS APIs, 53 for DNS). Empty = allow all.
  EOT
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = optional(string, "tcp")
    cidr_blocks = optional(list(string), ["0.0.0.0/0"])
  }))
  default = []
}

# ----- root volume -----
variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Encrypt the root EBS volume at rest (KMS)."
  type        = bool
  default     = true
}

# ----- optional extra data volume (e.g. /var/lib/mysql) -----
variable "create_data_volume" {
  description = "Create and attach a separate EBS data volume (clean snapshots/resize for DB data)."
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size in GB of the optional data volume."
  type        = number
  default     = 40
}

variable "data_volume_type" {
  description = "EBS type of the optional data volume."
  type        = string
  default     = "gp3"
}

variable "data_volume_device" {
  description = "Block device name for the data volume attachment (e.g. /dev/sdf)."
  type        = string
  default     = "/dev/sdf"
}

variable "data_volume_encrypted" {
  description = "Encrypt the data volume at rest (KMS)."
  type        = bool
  default     = true
}

variable "ebs_optimized" {
  description = "Enable EBS optimization. Nitro types (t3, m5, …) are EBS-optimized by default; set false only for types that don't support it."
  type        = bool
  default     = true
}

variable "user_data" {
  description = "Optional cloud-init user_data (bootstrap). null = none."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}

variable "metadata_http_tokens" {
  description = "IMDS token requirement: \"required\" enforces IMDSv2 (default, blocks SSRF cred theft); \"optional\" also allows IMDSv1 for legacy SDKs (e.g. boto 2.x) that cannot do the v2 token handshake."
  type        = string
  default     = "required"
  validation {
    condition     = contains(["required", "optional"], var.metadata_http_tokens)
    error_message = "metadata_http_tokens must be \"required\" or \"optional\"."
  }
}
