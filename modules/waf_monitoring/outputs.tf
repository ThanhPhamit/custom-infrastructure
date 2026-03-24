output "sns_topic_arn" {
  description = "ARN of the SNS topic for WAF alerts."
  value       = var.sns_topic_arn
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for WAF full logs."
  value       = aws_s3_bucket.waf_logs.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for WAF full logs."
  value       = aws_s3_bucket.waf_logs.id
}

output "dashboard_name" {
  description = "Name of the CloudWatch WAF dashboard."
  value       = var.enable_dashboard ? aws_cloudwatch_dashboard.waf[0].dashboard_name : ""
}

output "alarm_arns" {
  description = "Map of alarm name to ARN for all WAF alarms."
  value       = { for k, v in aws_cloudwatch_metric_alarm.waf_rules : k => v.arn }
}

output "alarm_names" {
  description = "List of CloudWatch alarm names created for WAF rules."
  value       = keys(aws_cloudwatch_metric_alarm.waf_rules)
}

# ── Athena outputs ──────────────────────────────────────────────────────────

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for WAF log queries."
  value       = var.enable_athena ? aws_athena_workgroup.waf[0].name : ""
}

output "athena_database_name" {
  description = "Glue database name containing the WAF logs table."
  value       = var.enable_athena ? aws_glue_catalog_database.waf[0].name : ""
}

output "athena_table_name" {
  description = "Glue table name for WAF logs."
  value       = var.enable_athena ? aws_glue_catalog_table.waf_logs[0].name : ""
}

output "athena_results_bucket" {
  description = "S3 bucket name for Athena query results."
  value       = var.enable_athena ? aws_s3_bucket.athena_results[0].id : ""
}

output "athena_query_context" {
  description = "Ready-to-use Athena query context for AI/Gemini integration."
  value = var.enable_athena ? {
    workgroup = aws_athena_workgroup.waf[0].name
    database  = aws_glue_catalog_database.waf[0].name
    table     = aws_glue_catalog_table.waf_logs[0].name
    example_queries = {
      top_blocked_ips = "SELECT httprequest.clientip, COUNT(*) AS cnt, action FROM waf_logs WHERE action = 'BLOCK' AND year = YEAR(CURRENT_DATE) AND month = MONTH(CURRENT_DATE) GROUP BY httprequest.clientip, action ORDER BY cnt DESC LIMIT 20;"
      counted_by_rule = "SELECT terminatingruleid, COUNT(*) AS cnt FROM waf_logs WHERE action = 'COUNT' AND year = YEAR(CURRENT_DATE) AND month = MONTH(CURRENT_DATE) GROUP BY terminatingruleid ORDER BY cnt DESC;"
      recent_attacks  = "SELECT from_unixtime(timestamp/1000) AS ts, httprequest.clientip, httprequest.uri, action, terminatingruleid FROM waf_logs WHERE year = YEAR(CURRENT_DATE) AND month = MONTH(CURRENT_DATE) AND day = DAY(CURRENT_DATE) ORDER BY timestamp DESC LIMIT 50;"
    }
  } : null
}
