output "resolver_endpoint_id" {
  description = "ID of the Route 53 Resolver outbound endpoint."
  value       = aws_route53_resolver_endpoint.this.id
}

output "resolver_endpoint_arn" {
  description = "ARN of the Route 53 Resolver outbound endpoint."
  value       = aws_route53_resolver_endpoint.this.arn
}

output "resolver_outbound_ip_addresses" {
  description = "Private IPs of the outbound ENIs, sorted for a stable order. Forwarded queries arrive at the on-prem DNS FROM these IPs — allow-list them in the on-prem firewall."
  value       = sort([for x in aws_route53_resolver_endpoint.this.ip_address : x.ip])
}

output "forward_rule_id" {
  description = "ID of the forwarding rule for forward_domain."
  value       = aws_route53_resolver_rule.forward.id
}

output "security_group_id" {
  description = "ID of the security group attached to the outbound endpoint."
  value       = aws_security_group.resolver.id
}
