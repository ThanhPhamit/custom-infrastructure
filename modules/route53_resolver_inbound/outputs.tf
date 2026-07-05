output "resolver_endpoint_id" {
  description = "ID of the Route 53 Resolver inbound endpoint."
  value       = aws_route53_resolver_endpoint.this.id
}

output "resolver_endpoint_arn" {
  description = "ARN of the Route 53 Resolver inbound endpoint."
  value       = aws_route53_resolver_endpoint.this.arn
}

output "resolver_inbound_ip_addresses" {
  description = "Private IP addresses of the resolver inbound ENIs, sorted for a stable order (ip_address is a set). On-prem DNS forwards AWS private zones to these IPs over the Site-to-Site VPN."
  value       = sort([for x in aws_route53_resolver_endpoint.this.ip_address : x.ip])
}

output "security_group_id" {
  description = "ID of the security group attached to the resolver inbound endpoint."
  value       = aws_security_group.resolver.id
}

output "query_log_group_name" {
  description = "Name of the CloudWatch log group receiving resolver query logs, or null when query logging is disabled."
  value       = try(aws_cloudwatch_log_group.resolver[0].name, null)
}
