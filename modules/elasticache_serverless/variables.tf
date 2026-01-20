variable "app_name" {}
variable "vpc_id" {}
variable "allowed_security_groups" {
  description = "List of security group IDs that are allowed to access the Redis instance"
  type        = list(string)
  default     = []
}
variable "subnet_ids" {}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
