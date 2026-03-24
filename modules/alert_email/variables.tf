# ---------------------------------------------------------------------------
# Required
# ---------------------------------------------------------------------------

variable "app_name" {
  description = "Application/project name. Used as prefix for all resource names."
  type        = string
}

variable "sender_email" {
  description = "Verified SES email address used as the From address."
  type        = string
}

variable "recipient_emails" {
  description = "Email addresses that receive alert notifications."
  type        = list(string)
  validation {
    condition     = length(var.recipient_emails) > 0
    error_message = "At least one recipient email is required."
  }
}

# ---------------------------------------------------------------------------
# Optional
# ---------------------------------------------------------------------------

variable "ses_region" {
  description = "AWS region for SES API calls. Leave empty to use the provider region. Override if SES is unavailable in your primary region (e.g. use ap-northeast-1 when deploying to ap-northeast-3)."
  type        = string
  default     = ""
}

variable "create_ses_identity" {
  description = "Create an SES email identity for the sender address. Disable if you manage SES identities externally or use domain-level verification."
  type        = bool
  default     = true
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for the forwarder Lambda (days)."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
