variable "app_name" {
  description = "Application name for resource naming and tagging"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the bastion host EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion host will be created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID where the bastion host will be placed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access. Only required when enable_ssh = true."
  type        = string
  default     = null
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the bastion host. Only used when enable_ssh = true."
  type        = list(string)
  default     = []
}

variable "create_eip" {
  description = "Whether to create an Elastic IP for the bastion host"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_scheduler" {
  description = "Enable EventBridge + Lambda scheduler for automatic start/stop"
  type        = bool
  default     = false
}

variable "scheduler_start_cron" {
  description = "Cron expression for starting instances (default: weekdays 7:00 AM GMT+7)"
  type        = string
  default     = "cron(0 0 ? * MON-FRI *)" # 0:00 UTC = 7:00 AM GMT+7
}

variable "scheduler_stop_cron" {
  description = "Cron expression for stopping instances (default: weekdays 7:00 PM GMT+7)"
  type        = string
  default     = "cron(0 12 ? * MON-FRI *)" # 12:00 UTC = 7:00 PM GMT+7
}

variable "scheduler_log_retention_in_days" {
  description = "Number of days to retain scheduler Lambda CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = var.scheduler_log_retention_in_days >= 1 && var.scheduler_log_retention_in_days <= 3653
    error_message = "scheduler_log_retention_in_days must be between 1 and 3653 days."
  }
}

# ----------------------------------------------------------------------------
# Access mode — SSH and/or SSM Session Manager
# Defaults keep the historical behaviour (SSH on, SSM off) so existing callers
# are unaffected.
# ----------------------------------------------------------------------------
variable "enable_ssh" {
  description = "Open inbound port 22 and use the key pair for classic SSH access."
  type        = bool
  default     = true
}

variable "enable_ssm" {
  description = <<-EOT
    Attach an IAM role so the host is reachable via SSM Session Manager
    (no inbound port, IAM-gated, audited in CloudTrail). Can be combined with
    enable_ssh. NOTE: the host must be able to reach the SSM service endpoints —
    either a public IP + Internet Gateway (set associate_public_ip_address /
    create_eip), a NAT gateway, or SSM interface VPC endpoints.
  EOT
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = <<-EOT
    Force-assign (true) or disable (false) a public IP. null = use the subnet's
    default. Useful for an SSM-only host with no EIP that still needs outbound
    internet to reach the SSM endpoints.
  EOT
  type        = bool
  default     = null
}

variable "ssm_session_iam_role_names" {
  description = <<-EOT
    Names of existing IAM roles to attach the scoped "start SSM session to this
    bastion" policy to. For IAM users, attach the output policy ARN manually.
    Only used when enable_ssm = true.
  EOT
  type        = list(string)
  default     = []
}
