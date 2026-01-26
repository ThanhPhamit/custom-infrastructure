variable "app_name" {
  description = "Application name used for bucket naming"
  type        = string
}

variable "allowed_origins" {
  description = "List of allowed origins for CORS (e.g., frontend domains for pre-signed URL uploads)"
  type        = list(string)
  default     = ["*"]
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}
