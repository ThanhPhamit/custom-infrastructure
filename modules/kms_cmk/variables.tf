variable "app_name" {
  description = "Naming prefix for the key + alias (e.g. myapp-prod). Alias becomes alias/<app_name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "description" {
  description = "Key description. Empty = a sensible default derived from app_name."
  type        = string
  default     = ""
}

variable "enable_key_rotation" {
  description = "Enable annual automatic key rotation."
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Waiting period (days) before the key is deleted after ScheduleKeyDeletion."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "multi_region" {
  description = "Create a multi-region key. false for a single-region CMK (default)."
  type        = bool
  default     = false
}

variable "key_administrator_arns" {
  description = "Extra IAM principal ARNs granted key ADMINISTRATION (beyond the account root, which always retains admin to prevent lockout)."
  type        = list(string)
  default     = []
}

variable "key_user_arns" {
  description = "IAM principal ARNs granted key USAGE (Encrypt/Decrypt/GenerateDataKey). Optional — account-root delegation already lets IAM policies grant usage, so leaving this empty and granting kms:Decrypt via the consumer's own IAM policy is the norm (avoids a key-policy ↔ role circular dependency)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the key (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}
