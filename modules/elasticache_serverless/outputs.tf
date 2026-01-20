
output "security_group_id" {
  value = aws_security_group.security_group.id
}

output "primary_endpoint" {
  value = aws_elasticache_serverless_cache.elasticache_serverless.endpoint
}

output "reader_endpoint" {
  value = aws_elasticache_serverless_cache.elasticache_serverless.reader_endpoint
}
