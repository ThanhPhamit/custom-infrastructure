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
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the bastion host"
  type        = list(string)
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
