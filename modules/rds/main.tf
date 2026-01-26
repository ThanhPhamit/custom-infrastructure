locals {
  # Use provided password or generate one
  use_generated_password = var.db_password == "" || var.db_password == null
  db_password            = local.use_generated_password ? random_password.rds[0].result : var.db_password

  # Parameter group name
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.db[0].name : var.parameter_group_name

  # Replica instance class defaults to primary
  replica_instance_class = var.replica_instance_class != null ? var.replica_instance_class : var.instance_class

  # Default PostgreSQL parameters for monitoring
  default_postgres_parameters = var.engine == "postgres" ? [
    {
      name         = "shared_preload_libraries"
      value        = "pg_stat_statements"
      apply_method = "pending-reboot"
    },
    {
      name         = "pg_stat_statements.track"
      value        = "all"
      apply_method = "pending-reboot"
    },
    {
      name         = "pg_stat_statements.max"
      value        = "10000"
      apply_method = "pending-reboot"
    },
    {
      name         = "track_activity_query_size"
      value        = "2048"
      apply_method = "pending-reboot"
    },
    {
      name         = "client_encoding"
      value        = "UTF8"
      apply_method = "pending-reboot"
    }
  ] : []

  # Merge default and custom parameters
  all_parameters = concat(local.default_postgres_parameters, var.custom_parameters)
}

#--------------------------------------------------------------
# Security Group
#--------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.app_name}-rds-sg"
  description = "Security group for RDS ${var.db_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-rds-sg"
    }
  )
}

# Ingress rules from security groups
resource "aws_security_group_rule" "db_from_sg" {
  count = length(var.restricted_security_group_ids)

  security_group_id        = aws_security_group.db.id
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = var.restricted_security_group_ids[count.index]
}

#--------------------------------------------------------------
# Password Management (Secrets Manager)
#--------------------------------------------------------------
resource "random_password" "rds" {
  count = local.use_generated_password ? 1 : 0

  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_uuid" "rds_secret_uuid" {
  count = local.use_generated_password ? 1 : 0
}

resource "aws_secretsmanager_secret" "rds_password" {
  count = local.use_generated_password ? 1 : 0

  name        = "${var.app_name}-rds-password-${substr(random_uuid.rds_secret_uuid[0].result, 0, 8)}"
  description = "RDS master password for ${var.db_name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  count = local.use_generated_password ? 1 : 0

  secret_id     = aws_secretsmanager_secret.rds_password[0].id
  secret_string = random_password.rds[0].result
}

#--------------------------------------------------------------
# DB Subnet Group
#--------------------------------------------------------------
locals {
  # Use provided subnet group name or create one
  db_subnet_group_name = var.db_subnet_group_name != null ? var.db_subnet_group_name : aws_db_subnet_group.db[0].name
}

resource "aws_db_subnet_group" "db" {
  count = var.db_subnet_group_name == null ? 1 : 0

  name        = "${var.app_name}-db-subnet-group"
  description = "DB subnet group for ${var.db_name}"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-db-subnet-group"
    }
  )
}

#--------------------------------------------------------------
# Parameter Group
#--------------------------------------------------------------
resource "aws_db_parameter_group" "db" {
  count = var.create_parameter_group ? 1 : 0

  name   = "${var.app_name}-${var.db_name}-params"
  family = var.engine_family

  dynamic "parameter" {
    for_each = local.all_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.db_name}-params"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#--------------------------------------------------------------
# IAM Role for Enhanced Monitoring
#--------------------------------------------------------------
module "rds_monitoring_role" {
  count = var.monitoring_interval > 0 ? 1 : 0

  source     = "../iam_role"
  name       = "${var.app_name}-rds-monitoring-role"
  identifier = "monitoring.rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  }
}

#--------------------------------------------------------------
# Primary RDS Instance
#--------------------------------------------------------------
resource "aws_db_instance" "primary" {
  identifier = var.db_name

  # Engine
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  port           = var.db_port

  # Database
  db_name  = var.db_database
  username = var.db_username
  password = local.db_password

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted

  # Network
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = local.db_subnet_group_name
  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : var.availability_zone

  # Parameters
  parameter_group_name = local.parameter_group_name

  # Backup
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  delete_automated_backups  = var.delete_automated_backups
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  copy_tags_to_snapshot     = true

  # Security
  deletion_protection = var.deletion_protection

  # Monitoring
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? module.rds_monitoring_role[0].iam_role_arn : null
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports

  apply_immediately = false

  tags = merge(
    var.tags,
    {
      Name = var.db_name
    }
  )
}

#--------------------------------------------------------------
# Read Replica (Optional)
#--------------------------------------------------------------
resource "aws_db_instance" "replica" {
  count = var.create_replica ? 1 : 0

  identifier           = "replica-${var.db_name}"
  replicate_source_db  = aws_db_instance.primary.identifier
  instance_class       = local.replica_instance_class
  parameter_group_name = local.parameter_group_name

  availability_zone = var.replica_availability_zone
  multi_az          = false # Replica cannot be multi-az

  storage_encrypted = var.storage_encrypted

  skip_final_snapshot     = true
  backup_retention_period = 7

  apply_immediately          = false
  auto_minor_version_upgrade = false

  tags = merge(
    var.tags,
    {
      Name = "replica-${var.db_name}"
    }
  )
}

#--------------------------------------------------------------
# S3 Integration (PostgreSQL Import/Export)
#--------------------------------------------------------------
resource "aws_iam_policy" "rds_s3_integration" {
  count = var.enable_s3_integration ? 1 : 0

  name   = "${var.app_name}-rds-s3-integration-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.rds_s3_integration[0].json

  tags = var.tags
}

module "rds_s3_export_role" {
  count = var.enable_s3_integration ? 1 : 0

  source     = "../iam_role"
  name       = "${var.app_name}-rds-s3-export-role"
  identifier = "rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = aws_iam_policy.rds_s3_integration[0].arn
  }
}

module "rds_s3_import_role" {
  count = var.enable_s3_integration ? 1 : 0

  source     = "../iam_role"
  name       = "${var.app_name}-rds-s3-import-role"
  identifier = "rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = aws_iam_policy.rds_s3_integration[0].arn
  }
}

resource "aws_db_instance_role_association" "db_export" {
  count = var.enable_s3_integration ? 1 : 0

  db_instance_identifier = aws_db_instance.primary.identifier
  feature_name           = "s3Export"
  role_arn               = module.rds_s3_export_role[0].iam_role_arn
}

resource "aws_db_instance_role_association" "db_import" {
  count = var.enable_s3_integration ? 1 : 0

  db_instance_identifier = aws_db_instance.primary.identifier
  feature_name           = "s3Import"
  role_arn               = module.rds_s3_import_role[0].iam_role_arn
}
