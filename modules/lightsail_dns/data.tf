# =============================================================================
# Data sources — lookup the existing Route 53 hosted zone.
# The zone is assumed to pre-exist (usually created once per account/domain).
# =============================================================================

data "aws_route53_zone" "this" {
  name         = var.dns_zone
  private_zone = var.private_zone
}
