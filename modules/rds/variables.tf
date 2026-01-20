variable "app_name" {}
variable "db_name" {}
variable "db_username" {}

variable "db_port" {
  type = number
}

variable "db_database" {
  type = string
}

variable "vpc_id" {}
variable "private_subnet_ids" {}
variable "restricted_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs that are allowed to access the RDS instance"
}

variable "engine" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}
variable "parameter_group_name" {
  type = string
}
variable "multi_az" {
  type = bool
}

variable "allocated_storage" {
  type    = number
  default = 20
}
variable "max_allocated_storage" {
  type    = number
  default = 20
}
variable "availability_zone" {}
variable "enabled_cloudwatch_logs_exports" {
  type = list(string)
}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
