resource "random_uuid" "sg_uuid" {}

resource "aws_security_group" "security_group" {
  name   = "${var.app_name}-els"
  vpc_id = var.vpc_id

  tags = merge(
    {
      Name = "${var.app_name}-els"
    },
    var.tags,
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

resource "aws_elasticache_serverless_cache" "elasticache_serverless" {
  name        = "${var.app_name}-els"
  description = "Elasticache Serverless for ${var.app_name}"

  engine = "valkey"
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
  daily_snapshot_time      = "18:00"
  major_engine_version     = "8"
  snapshot_retention_limit = 1
  security_group_ids       = [aws_security_group.security_group.id]
  subnet_ids               = var.subnet_ids

  tags = merge(
    {
      Name = "${var.app_name}-els-${substr(random_uuid.sg_uuid.result, 0, 6)}"
    },
    var.tags,
  )
}
