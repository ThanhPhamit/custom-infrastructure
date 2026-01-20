# Get VPC information including CIDR block
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Get AWS managed CloudFront global origin-facing prefix list
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.allow_cloudfront_prefix_list ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  vpc_cidrs = [for assoc in data.aws_vpc.selected.cidr_block_associations : assoc.cidr_block]
}
