# Use locals to generate cluster IDs based on naming pattern
locals {
  # Generate cluster IDs based on standard ElastiCache naming pattern
  cluster_ids = [for i in range(var.number_cache_clusters) : "${aws_elasticache_replication_group.redis.replication_group_id}-${format("%03d", i + 1)}"]
}

# Get cluster details for each generated cluster ID
data "aws_elasticache_cluster" "redis_clusters" {
  for_each   = toset(local.cluster_ids)
  cluster_id = each.value
}

# Create a flattened map of all cache nodes
locals {
  cache_nodes = merge([
    for cluster_id, cluster_data in data.aws_elasticache_cluster.redis_clusters : {
      for node in cluster_data.cache_nodes :
      "${cluster_id}-${node.id}" => {
        cluster_id = cluster_id
        node_id    = node.id
        az         = node.availability_zone
        address    = node.address
        port       = node.port
      }
    }
  ]...)
}
