variable "domain" {
  description = "Base domain name for the certificate (e.g., welfan.internal)"
  type        = string
}

variable "app_dns_zone" {
  description = "DNS zone name"
  type        = string
}

variable "organization_name" {
  description = "Organization name for the certificate"
  type        = string
  default     = "Internal Organization"
}

variable "ca_validity_days" {
  description = "CA certificate validity period in days"
  type        = number
  default     = 3650 # 10 years
}

variable "server_validity_days" {
  description = "Server certificate validity period in days"
  type        = number
  default     = 365 # 1 year
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cert_output_path" {
  description = "Path where certificates will be created (relative to the environment folder)"
  type        = string
  default     = "certificates"
}
