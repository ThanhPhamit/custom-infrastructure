variable "name" {
  description = "Name of the IAM role"
  type        = string
}
variable "policy_arns_map" {
  description = "Map of policy ARNs to attach to the IAM role"
  type        = map(string)
}
variable "identifier" {
  description = "Service principal allowed to assume the role (e.g. lambda.amazonaws.com)"
  type        = string
}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}