
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
