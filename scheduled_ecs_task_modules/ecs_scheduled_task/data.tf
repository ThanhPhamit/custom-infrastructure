data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  cluster_name   = var.cluster_name != null ? var.cluster_name : var.app_name
  log_group_name = var.log_group_name != null ? var.log_group_name : "/ecs/${var.app_name}"
}
