variable "name" {}
variable "policy_arns_map" {
  description = "Map of policy ARNs to attach to the IAM role"
  type        = map(string)
}
variable "identifier" {}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}