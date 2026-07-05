################################################################################
# Locals
################################################################################

locals {
  # Major engine version drives the parameter-group family (e.g. 16 -> aurora-postgresql16).
  major              = split(".", var.engine_version)[0]
  param_group_family = "aurora-postgresql${local.major}"

  # Per-instance alarm map (only populated when alarms are enabled). Built from known
  # inputs (not aws_rds_cluster_instance attributes) so the for_each keys are resolvable
  # at plan time — the identifiers mirror the instances' "identifier" exactly.
  instance_alarms = var.enable_alarms ? {
    for i in range(var.instance_count) :
    "${var.app_name}-aurora-${i}" => "${var.app_name}-aurora-${i}"
  } : {}
}

################################################################################
# DB subnet group
################################################################################

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.app_name}-aurora-subnets-"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-subnets"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security group (ingress 5432 only; no egress)
################################################################################

resource "aws_security_group" "db" {
  name_prefix = "${var.app_name}-aurora-"
  description = "Aurora PostgreSQL ingress on 5432 for ${var.app_name}; no egress."
  vpc_id      = var.vpc_id

  # Rules live in separate aws_vpc_security_group_*_rule resources so that rule
  # changes never replace the SG (and thus never churn its consumers).
  # No egress rules are defined on purpose: the SG allows no outbound traffic.

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-sg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL access from ${each.value} (e.g. on-prem over S2S VPN)."
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-5432"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Cluster parameter group (forces TLS via rds.force_ssl)
################################################################################

resource "aws_rds_cluster_parameter_group" "this" {
  name_prefix = "${var.app_name}-aurora-cluster-pg-"
  family      = local.param_group_family
  description = "Custom Aurora PostgreSQL cluster parameter group for ${var.app_name}."

  dynamic "parameter" {
    for_each = var.force_ssl ? [1] : []

    content {
      name         = "rds.force_ssl"
      value        = "1"
      apply_method = "pending-reboot"
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-cluster-pg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Enhanced Monitoring IAM role (gated on monitoring_interval > 0)
################################################################################

resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name_prefix        = "${var.app_name}-aurora-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-monitoring-role"
    ManagedBy = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# Aurora cluster
################################################################################

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.app_name}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username
  # Password is managed by RDS in Secrets Manager; never set master_password here.
  manage_master_user_password = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  apply_immediately   = var.apply_immediately

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  copy_tags_to_snapshot           = true

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Aurora cluster instances
################################################################################

resource "aws_rds_cluster_instance" "this" {
  # for_each over a stable key set so scaling down a reader does not re-index and
  # destroy/recreate the wrong instance (count would).
  for_each = toset([for i in range(var.instance_count) : tostring(i)])

  identifier         = "${var.app_name}-aurora-${each.key}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.instance_class
  ca_cert_identifier = var.ca_cert_identifier

  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-${each.key}"
    ManagedBy = "Terraform"
  })
}

################################################################################
# RDS event subscription (optional)
################################################################################

resource "aws_db_event_subscription" "this" {
  # Gated on a plan-time-known bool — the topic ARN itself is usually
  # "known after apply", which cannot drive count.
  count = var.enable_event_subscription ? 1 : 0

  name      = "${var.app_name}-aurora-events"
  sns_topic = var.event_subscription_sns_topic_arn

  source_type      = "db-cluster"
  source_ids       = [aws_rds_cluster.this.id]
  event_categories = ["failover", "failure", "maintenance", "notification"]

  tags = merge(var.tags, {
    Name      = "${var.app_name}-aurora-events"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Per-instance CPUUtilization alarms (optional)
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = local.instance_alarms

  alarm_name          = "${each.value}-cpu"
  alarm_description   = "CPUUtilization above ${var.alarm_cpu_threshold}% for Aurora instance ${each.value}."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alarm_cpu_threshold
  period              = 300
  evaluation_periods  = 3

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = var.alarm_actions

  tags = merge(var.tags, {
    Name      = "${each.value}-cpu"
    ManagedBy = "Terraform"
  })
}
