variable "path_prefix" {
  description = "Path prefix for all parameters, no trailing slash (e.g. /myapp/prod). Each parameter is created at <path_prefix>/<key>."
  type        = string

  validation {
    condition     = can(regex("^/[a-zA-Z0-9._/-]+[^/]$", var.path_prefix))
    error_message = "path_prefix must start with '/' and not end with '/'."
  }
}

variable "kms_key_id" {
  description = "CMK key id/ARN used to encrypt the SecureString parameters."
  type        = string
}

variable "parameters" {
  description = <<-EOT
    Map of parameter short-name => { description }. Each is created as a SecureString with a
    PLACEHOLDER value; the real value is set OUT-OF-BAND (aws ssm put-parameter). Terraform
    ignore_changes on value means it never overwrites the operator-set value on later applies.
  EOT
  type = map(object({
    description = string
  }))
}

variable "tier" {
  description = "SSM parameter tier (Standard | Advanced | Intelligent-Tiering)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.tier)
    error_message = "tier must be Standard, Advanced, or Intelligent-Tiering."
  }
}

variable "placeholder_value" {
  description = "Initial placeholder written on create (immediately overwritten out-of-band; ignored thereafter)."
  type        = string
  default     = "REPLACE_ME_SET_OUT_OF_BAND"
}

variable "tags" {
  description = "Tags applied to every parameter (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}
