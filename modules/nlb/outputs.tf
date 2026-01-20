output "nlb_arn" {
  value = aws_lb.nlb.arn
}

output "nlb_security_group_id" {
  value = aws_security_group.security_group.id
}

output "nlb_arn_suffix" {
  value = aws_lb.nlb.arn_suffix
}

output "id" {
  value = aws_lb.nlb.id
}

output "domain" {
  value = aws_lb.nlb.dns_name
}

output "dns_name" {
  value = aws_lb.nlb.dns_name
}

output "zone_id" {
  value = aws_lb.nlb.zone_id
}

# TLS listener outputs (when enabled)
output "lb_listener_tls_prod_arn" {
  value = var.enable_tls_termination ? aws_lb_listener.tls_prod[0].arn : null
}

output "lb_listener_tls_test_arn" {
  value = var.enable_tls_termination ? aws_lb_listener.tls_test[0].arn : null
}

# IP addresses output - simplified approach
output "nlb_ip_addresses" {
  description = "List of IP addresses assigned to the NLB"
  value = var.use_fixed_ips ? [
    for mapping in var.subnet_mappings : mapping.private_ipv4_address if mapping.private_ipv4_address != null
  ] : ["Dynamic IPs - check AWS console for actual IPs"]
}

# For backward compatibility
output "fixed_ip_addresses" {
  description = "List of fixed private IP addresses assigned to the NLB (when using fixed IPs)"
  value = var.use_fixed_ips ? [
    for mapping in var.subnet_mappings : mapping.private_ipv4_address if mapping.private_ipv4_address != null
  ] : []
}

# Elastic IP addresses for internet-facing NLBs
output "elastic_ip_addresses" {
  description = "List of Elastic IP addresses assigned to the NLB (for internet-facing NLBs)"
  value       = var.use_fixed_ips && !var.nlb_internal ? [for mapping in aws_lb.nlb.subnet_mapping : mapping.allocation_id if mapping.allocation_id != null] : []
}
