variable "app_name" {}
variable "domain_name" {
  type    = string
  default = null
}
# variable "route_53_zone_id" {
#   type = string
# }
variable "email_identities" {
  description = "List of email identities to be verified in SES"
  type        = list(string)
}

variable "create_smtp_user" {
  description = "Whether to create SMTP IAM user and credentials"
  type        = bool
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "email_templates" {
  description = "List of email templates to create in SES"
  type = list(object({
    name    = string
    subject = string
    html    = string
    text    = string
  }))
  default = []
}
