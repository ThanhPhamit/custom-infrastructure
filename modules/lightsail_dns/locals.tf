locals {
  zone_id = data.aws_route53_zone.this.zone_id

  # If caller passed 'records', use it as-is. Otherwise fall back to
  # the (subdomains + target_ip) shortcut — one A record per subdomain.
  fallback_records = {
    for s in var.subdomains : s => {
      name   = s
      type   = "A"
      ttl    = var.ttl
      values = [var.target_ip]
    }
  }

  effective_records = length(var.records) > 0 ? var.records : local.fallback_records
}
