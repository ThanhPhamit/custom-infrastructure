variable "domain" {}
variable "app_dns_zone" {}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
variable "create_expiry_alarm" {
  description = <<-EOT
    Alarm when the regional certificate is close to expiry.

    ACM renews automatically, but only while its DNS validation record still exists and still
    resolves. Nothing about a broken validation record is visible until renewal fails, and renewal
    happens once a year -- so the failure surfaces as sudden TLS errors on a date nobody is watching.
    Seen in practice: two Terraform roots held the same validation record
    addresses, and destroying one would have silently disarmed renewal seven months later.

    Cheap insurance against a once-a-year, no-warning failure.
  EOT
  type        = bool
  default     = false
}

variable "expiry_alarm_sns_topic_arn" {
  description = "SNS topic for the expiry alarm. Required when create_expiry_alarm is true."
  type        = string
  default     = ""
}

variable "expiry_alarm_days" {
  description = "Fire when the certificate has fewer than this many days left. ACM starts attempting renewal around 60 days out, so a threshold near 30 means renewal has already had a month to succeed and did not -- that is a real signal, not a countdown."
  type        = number
  default     = 30

  validation {
    condition     = var.expiry_alarm_days > 0 && var.expiry_alarm_days < 60
    error_message = "expiry_alarm_days must be between 1 and 59: ACM begins renewal around 60 days out, so a higher threshold alarms on the normal renewal window."
  }
}
