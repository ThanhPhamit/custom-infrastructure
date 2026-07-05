output "security_group_id" {
  description = "ID of the shared security group attached to every interface endpoint."
  value       = aws_security_group.endpoints.id
}

output "endpoint_ids" {
  description = "Map of short service name => VPC endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.this : k => v.id }
}

output "endpoint_dns_entries" {
  description = "Map of short service name => the endpoint's dns_entry list (each entry has dns_name and hosted_zone_id), useful for hybrid DNS / Resolver forwarding."
  value       = { for k, v in aws_vpc_endpoint.this : k => v.dns_entry }
}
