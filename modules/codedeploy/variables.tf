variable "aws_region" {}
variable "app_name" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "lb_listener_prod_arn" {}
variable "lb_listener_test_arn" {}
variable "lb_target_group_blue_name" {}
variable "lb_target_group_green_name" {}
variable "task_definition_arn" {
  type        = string
  description = "The ARN of the task definition including revision number"
}
variable "container_name" {
  type        = string
  description = "The name of the container"
}
variable "container_port" {
  type        = number
  description = "The port number on the container"
}
variable "deployment_config_name" {
  type        = string
  description = "The name of the deployment configuration"
  default     = "CodeDeployDefault.ECSAllAtOnce"
}
variable "revision_appspec_key" {
  type        = string
  description = "The key of the AppSpec file in the revision"
  default     = "appspec.yaml"
}
variable "revision_bundle_type" {
  type        = string
  description = "The type of the revision bundle"
  default     = "yaml"
}

variable "appspec_retention_days" {
  type        = number
  description = "Number of days to retain appspec files in S3 (default 90 days for quarterly rollback)"
  default     = 90
}

variable "appspec_noncurrent_retention_days" {
  type        = number
  description = "Number of days to retain noncurrent versions of appspec files"
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
