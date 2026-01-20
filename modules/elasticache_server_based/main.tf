resource "random_uuid" "sg_uuid" {}

resource "aws_security_group" "security_group" {
  name   = "${var.app_name}-elasticache"
  vpc_id = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-elasticache"
    }
  )

  egress = []
}

resource "aws_security_group_rule" "allow_from_security_groups" {
  count = length(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.security_group.id
  source_security_group_id = var.allowed_security_groups[count.index]
}

resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name        = "${var.app_name}-elasticache-subnet"
  description = "Redis Subnet Group"

  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-elasticache-subnet"
    }
  )
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.app_name}-redis"
  description          = var.app_name
  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.number_cache_clusters
  parameter_group_name = var.parameter_group_name
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.elasticache_subnet_group.name

  security_group_ids = [aws_security_group.security_group.id]

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window

  maintenance_window = var.maintenance_window

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  transit_encryption_enabled = var.transit_encryption_enabled
  at_rest_encryption_enabled = var.at_rest_encryption_enabled

  apply_immediately = var.apply_immediately


  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-redis"
    }
  )
}
