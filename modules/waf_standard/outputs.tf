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

output "web_acl_metric_name" {
  description = "The CloudWatch metric name for the web ACL (from visibility_config)."
  value       = "${var.app_name}-WAF-Main"
}

output "active_rules" {
  description = "Map of active rule keys to their CloudWatch metric name and action mode. Pass to waf_monitoring."
  value = merge(
    {
      # Always-on rules
      ip_reputation = { metric_name = "${var.app_name}-IPReputation", action_mode = var.ip_reputation_action_mode }
      rate_limit    = { metric_name = "${var.app_name}-RateLimit", action_mode = var.rate_limit_action_mode }
      crs           = { metric_name = "${var.app_name}-CommonRuleSet", action_mode = var.crs_action_mode }
    },
    local.effective_enable_ip_allowlist ? { ip_allowlist = { metric_name = "${var.app_name}-IPAllowlist", action_mode = "allow" } } : {},
    local.effective_enable_geo_block && length(var.blocked_countries) > 0 ? { geo_block = { metric_name = "${var.app_name}-GeoBlock", action_mode = var.geo_block_action_mode } } : {},
    local.effective_enable_anonymous_ip_list ? { anonymous_ip = { metric_name = "${var.app_name}-AnonymousIPList", action_mode = var.anonymous_ip_action_mode } } : {},
    local.effective_enable_body_size_restriction ? { body_size = { metric_name = "${var.app_name}-BodySizeRestriction", action_mode = var.body_size_action_mode } } : {},
    local.effective_enable_sql_injection_protection ? { sql_injection = { metric_name = "${var.app_name}-SQLiRuleSet", action_mode = var.sql_injection_action_mode } } : {},
    local.effective_enable_known_bad_inputs ? { known_bad_inputs = { metric_name = "${var.app_name}-KnownBadInputs", action_mode = var.known_bad_inputs_action_mode } } : {},
    local.effective_enable_bot_control ? { bot_control = { metric_name = "${var.app_name}-BotControl", action_mode = var.bot_control_action_mode } } : {},
  )
}
