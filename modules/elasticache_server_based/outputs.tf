
output "security_group_id" {
  value = aws_security_group.security_group.id
}

output "primary_endpoint_address" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "reader_endpoint_address" {
  value = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "primary_endpoint_port" {
  value = aws_elasticache_replication_group.redis.port
}

output "replication_group_id" {
  description = "The replication group ID"
  value       = aws_elasticache_replication_group.redis.replication_group_id
}

output "cluster_id" {
  description = "The cluster ID"
  value       = aws_elasticache_replication_group.redis.id
}
output "cache_nodes" {
  description = "Map of all cache nodes with their details"
  value       = local.cache_nodes
}

output "engine_log_group_arn" {
  description = "ARN of the engine-log CloudWatch log group (null when log delivery disabled)."
  value       = try(aws_cloudwatch_log_group.engine_log[0].arn, null)
}

output "slow_log_group_arn" {
  description = "ARN of the slow-log CloudWatch log group (null when log delivery disabled)."
  value       = try(aws_cloudwatch_log_group.slow_log[0].arn, null)
}

output "log_group_arns" {
  description = "List of CloudWatch log group ARNs created by log delivery (empty when disabled)."
  value       = compact([try(aws_cloudwatch_log_group.engine_log[0].arn, ""), try(aws_cloudwatch_log_group.slow_log[0].arn, "")])
}
