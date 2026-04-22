variable "app_name" {
  description = "Application name for resource naming (e.g., dev-care-hub)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens (3-50 chars) and start/end with alphanumeric."
  }
}

variable "region" {
  description = "AWS region for the Lightsail instance"
  type        = string
  default     = "ap-northeast-1"
}

variable "availability_zone_suffix" {
  description = "AZ suffix (a, c, d) appended to region"
  type        = string
  default     = "a"

  validation {
    condition     = can(regex("^[a-z]$", var.availability_zone_suffix))
    error_message = "availability_zone_suffix must be a single lowercase letter (e.g., a, c, d)."
  }
}

variable "blueprint_id" {
  description = "Lightsail OS blueprint (e.g., ubuntu_24_04). Must be a supported Ubuntu blueprint."
  type        = string
  default     = "ubuntu_24_04"

  validation {
    condition     = can(regex("^ubuntu_\\d+_\\d+$", var.blueprint_id))
    error_message = "blueprint_id must match an Ubuntu blueprint pattern (e.g., ubuntu_24_04, ubuntu_22_04)."
  }
}

variable "bundle_id" {
  description = "Lightsail instance plan (nano_3_2=512MB/$5, micro_3_2=1GB/$7, small_3_2=2GB/$12, medium_3_2=4GB/$24)"
  type        = string
  default     = "medium_3_2"

  validation {
    condition     = can(regex("^(nano|micro|small|medium|large|xlarge|2xlarge)_3_\\d+$", var.bundle_id))
    error_message = "bundle_id must be a valid Lightsail bundle (e.g., small_3_2, medium_3_2, large_3_2)."
  }
}

variable "key_pair_name" {
  description = "SSH key pair name. Set to null to skip key pair creation."
  type        = string
  default     = null
}

variable "public_key" {
  description = "SSH public key content (required if key_pair_name is set)"
  type        = string
  default     = ""

  validation {
    condition     = var.public_key == "" || can(regex("^ssh-(rsa|ed25519|ecdsa) ", var.public_key))
    error_message = "public_key must start with 'ssh-rsa ', 'ssh-ed25519 ', or 'ssh-ecdsa '."
  }
}

variable "user_data" {
  description = "Cloud-init user data script to run on first boot"
  type        = string
  default     = null
}

# ===== Firewall =====
# Caller-defined port rules. No ports are opened by default — empty list
# means the instance has no public firewall rules (not reachable).
variable "port_rules" {
  description = <<-EOT
    List of Lightsail firewall port rules. Each entry mirrors an aws_lightsail_instance_public_ports.port_info block.
    Example:
      [
        { protocol = "tcp", from_port = 22,  to_port = 22,  cidrs = ["203.0.113.0/24"] },
        { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"] },
      ]
  EOT
  type = list(object({
    protocol  = string
    from_port = number
    to_port   = number
    cidrs     = list(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.port_rules : contains(["tcp", "udp", "icmp", "all"], r.protocol)
    ])
    error_message = "Each port rule protocol must be one of: tcp, udp, icmp, all."
  }

  validation {
    condition = alltrue([
      for r in var.port_rules : length(r.cidrs) > 0 && alltrue([
        for c in r.cidrs : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}/\\d{1,2}$", c))
      ])
    ])
    error_message = "Each port rule must have at least one valid IPv4 CIDR in cidrs."
  }
}

# ===== IAM User =====

variable "create_iam_user" {
  description = "Create an IAM user with access keys stored in Secrets Manager. Required for Lightsail app access to AWS services (S3, SES, SNS, ECR) — Lightsail has no user-controlled instance role."
  type        = bool
  default     = false
}

variable "iam_policies" {
  description = <<-EOT
    Map of managed IAM policies to attach to the created user.
    Key = policy name suffix (e.g., "s3-access"); value = JSON policy document.
    Typically built by the caller via data.aws_iam_policy_document and .json.
    Only applied when create_iam_user = true.
  EOT
  type        = map(string)
  default     = {}
}

# ===== Tags =====

variable "tags" {
  description = "Tags to apply to all resources (merged with Name + ManagedBy)"
  type        = map(string)
  default     = {}
}
