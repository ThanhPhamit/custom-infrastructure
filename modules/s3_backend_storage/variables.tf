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

variable "force_destroy" {
  description = "Allow Terraform to destroy the bucket even if it still contains objects (incl. versions). Default false preserves prior behavior."
  type        = bool
  default     = false
}

variable "create_cors_configuration" {
  description = "Whether to create the CORS configuration for pre-signed URL uploads. Default true preserves prior behavior."
  type        = bool
  default     = true
}

variable "create_access_policy" {
  description = "Whether to create the IAM policy granting backend get/put/delete/list access. Default true preserves prior behavior."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to merge onto the bucket. Default {} preserves prior behavior."
  type        = map(string)
  default     = {}
}
