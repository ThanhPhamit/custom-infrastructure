variable "app_name" {
  type = string
}

variable "slack_workspace_id" {
  type = string
}

variable "slack_channel_id" {
  type = string
}

variable "slack_channel_name" {
  type = string
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
