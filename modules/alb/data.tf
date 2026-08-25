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

  # Origin mTLS (verify mode): create a trust store from the given S3 CA bundle only when mTLS is on,
  # mode is verify, AND the caller didn't pass an existing trust store. Resolve the effective ARN.
  # When a forward target group is supplied, the :443 listener forwards to it instead of returning a
  # fixed "ok" (the default ECS/CodeDeploy shape). Lets the module serve a simple ALB→target use case.
  prod_forward = var.forward_target_group_arn != ""

  create_trust_store = var.enable_mutual_auth && var.mutual_auth_mode == "verify" && var.mutual_auth_trust_store_arn == ""
  mutual_auth_trust_store = (var.enable_mutual_auth && var.mutual_auth_mode == "verify") ? (
    var.mutual_auth_trust_store_arn != "" ? var.mutual_auth_trust_store_arn : aws_lb_trust_store.this[0].arn
  ) : null
}
