output "web_acl_arn" {
  description = "ARN of the WAF Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the WAF Web ACL (used in CloudFront distribution's web_acl_id field)."
  value       = aws_wafv2_web_acl.this.id
}

output "waf_arn" {
  description = "ARN of the WAF Web ACL – alias for use in aws_wafv2_web_acl_association (REGIONAL)."
  value       = aws_wafv2_web_acl.this.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf_logs.name
}

output "ip_set_arn" {
  description = "ARN of the IP allowlist set. Empty string when IP allowlist is disabled."
  value       = local.effective_enable_ip_allowlist ? aws_wafv2_ip_set.allowed_ips[0].arn : ""
}

output "service_type" {
  description = "The service_type preset used for this WAF instance."
  value       = var.service_type
}

output "effective_rate_limit" {
  description = "The effective rate limit applied (after preset/override resolution)."
  value       = local.effective_rate_limit
}
