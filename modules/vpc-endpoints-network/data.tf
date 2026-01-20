data "aws_vpc" "this" {
  id = var.vpc_id
}
data "aws_caller_identity" "user" {}
data "aws_region" "current" {}

# Add this to your data.tf file:
data "aws_subnet" "selected" {
  count = length(var.subnet_ids)
  id    = var.subnet_ids[count.index]
}
