variable "app_name" {}
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
variable "allowed_security_group_ids" {
  description = "List of security group IDs that are allowed to access VPC endpoints"
  type        = list(string)
}
variable "route_table_ids" {
  description = "List of route table IDs"
  type        = list(string)
}
variable "enable_ecs_exec_endpoints" {
  description = "Enable VPC endpoints required for ECS Exec (SSM, SSM Messages, EC2 Messages)"
  type        = bool
  default     = false
}

variable "vpn_client_cidr_blocks" {
  description = "List of VPN client CIDR blocks that are allowed to access VPC endpoints"
  type        = list(string)
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
