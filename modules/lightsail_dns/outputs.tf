output "dns_records" {
  description = "Map of record key → FQDN for created DNS records"
  value       = { for k, r in aws_route53_record.this : k => r.fqdn }
}

output "record_names" {
  description = "List of FQDNs created"
  value       = [for r in aws_route53_record.this : r.fqdn]
}

output "zone_id" {
  description = "Route 53 zone ID used"
  value       = data.aws_route53_zone.this.zone_id
}
