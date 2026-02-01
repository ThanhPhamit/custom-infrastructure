variable "repository_name" {
  type = string
}

variable "image_retention_count" {
  description = "Number of tagged images to retain (DEV: 20, STG: 50, PROD: 100)"
  type        = number
  default     = 50
}

variable "untagged_retention_days" {
  description = "Days to keep untagged images before deletion"
  type        = number
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
