# output "cpu_utilization_warning_alarm_arn" {
#   description = "ARN of the CPU utilization warning alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_cpu_utilization_warning.arn
# }

# output "cpu_utilization_critical_alarm_arn" {
#   description = "ARN of the CPU utilization critical alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_cpu_utilization_critical.arn
# }

# output "memory_usage_warning_alarm_arn" {
#   description = "ARN of the memory usage warning alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_memory_usage_warning.arn
# }

# output "memory_usage_critical_alarm_arn" {
#   description = "ARN of the memory usage critical alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_memory_usage_critical.arn
# }

# output "cache_hit_ratio_alarm_arn" {
#   description = "ARN of the cache hit ratio alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_cache_hit_ratio.arn
# }

# output "connections_alarm_arn" {
#   description = "ARN of the connections alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_curr_connections.arn
# }

# output "evictions_alarm_arn" {
#   description = "ARN of the evictions alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_evictions.arn
# }

# output "network_bytes_in_alarm_arn" {
#   description = "ARN of the network bytes in alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_network_bytes_in.arn
# }

# output "network_bytes_out_alarm_arn" {
#   description = "ARN of the network bytes out alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_network_bytes_out.arn
# }

# output "replication_lag_alarm_arn" {
#   description = "ARN of the replication lag alarm"
#   value       = length(aws_cloudwatch_metric_alarm.elasticache_replication_lag) > 0 ? aws_cloudwatch_metric_alarm.elasticache_replication_lag[0].arn : null
# }

# output "engine_cpu_utilization_alarm_arn" {
#   description = "ARN of the engine CPU utilization alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_engine_cpu_utilization.arn
# }

# output "get_commands_alarm_arn" {
#   description = "ARN of the GET commands alarm"
#   value       = aws_cloudwatch_metric_alarm.elasticache_get_commands.arn
# }
