# =============================================================================
# Route 53 DNS Records — generic module
# Creates any set of Route 53 records (A/AAAA/CNAME/TXT/...) in a pre-existing
# hosted zone. Not coupled to Lightsail — usable for any target (ALB, EC2, etc.)
# =============================================================================

resource "aws_route53_record" "this" {
  for_each = local.effective_records

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
