resource "aws_security_group" "db" {
  name        = "${var.app_name}-db"
  description = "security group for db"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-sg for db"
  }
}

# resource "aws_security_group_rule" "db" {
#   security_group_id        = aws_security_group.db.id
#   from_port                = var.db_port
#   to_port                  = var.db_port
#   protocol                 = "tcp"
#   source_security_group_id = var.alb_security_group_id
#   type                     = "ingress"
# }

# batch job から db にアクセスするためのセキュリティグループルール
# resource "aws_security_group_rule" "postgresql-rule-for-ecs-scheduler" {
#   security_group_id        = aws_security_group.db_sg.id
#   from_port                = var.db_port
#   to_port                  = var.db_port
#   protocol                 = "tcp"
#   source_security_group_id = var.ecs_scheduler_security_group_id
#   type                     = "ingress"
# }

resource "aws_db_subnet_group" "db" {
  name        = "${var.app_name}-db"
  description = "db subnet group for ${var.db_name}"
  subnet_ids  = var.private_subnet_ids
}

resource "aws_db_parameter_group" "db" {
  name   = var.db_name
  family = var.engine_family

  # 詳細モニタリングを有効化するために必要な設定
  parameter {
    apply_method = "pending-reboot"
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "pg_stat_statements.track"
    value        = "all"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "pg_stat_statements.max"
    value        = "10000"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "track_activity_query_size"
    value        = "2048"
  }

  # encoding
  parameter {
    apply_method = "pending-reboot"
    name         = "client_encoding"
    value        = "UTF8"
  }
}

module "rds_monitoring_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-rds-monitoring-role"
  identifier = "monitoring.rds.amazonaws.com"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "db" {
  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.db.name

  identifier          = var.db_name
  db_name             = var.db_database
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.db.name

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  max_allocated_storage           = var.max_allocated_storage
  multi_az                        = var.multi_az
  availability_zone               = var.availability_zone

  storage_encrypted = true

  deletion_protection   = true
  copy_tags_to_snapshot = true

  backup_retention_period  = 35
  backup_window            = "20:57-21:27"
  delete_automated_backups = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  monitoring_interval = 60
  monitoring_role_arn = module.rds_monitoring_role.iam_role_arn

  apply_immediately = false
}

resource "aws_db_instance" "replica-postgresql-rds" {
  replicate_source_db  = aws_db_instance.db.identifier
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.db.name

  availability_zone = var.replica_availability_zone
  identifier        = "replica-${var.db_name}"
  multi_az          = var.multi_az

  storage_encrypted = true

  skip_final_snapshot = true

  backup_retention_period = 7

  apply_immediately = false

  auto_minor_version_upgrade = false
}


# dump 作成の必要が出たときのために
# postgres の s3 import export を有効にしておく
resource "aws_iam_policy" "rds_s3_integration" {
  name   = "${var.app_name}-rds-s3-integration-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.rds_s3_integration.json
}

module "rds_s3_export_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-rds-s3-export-role"
  identifier = "rds.amazonaws.com"
  policy_arn = aws_iam_policy.rds_s3_integration.arn
}

module "rds_s3_import_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-rds-s3-import-role"
  identifier = "rds.amazonaws.com"
  policy_arn = aws_iam_policy.rds_s3_integration.arn
}

resource "aws_db_instance_role_association" "db_export" {
  db_instance_identifier = aws_db_instance.db.identifier
  feature_name           = "s3Export"
  role_arn               = module.rds_s3_export_role.iam_role_arn
}

resource "aws_db_instance_role_association" "db_import" {
  db_instance_identifier = aws_db_instance.db.identifier
  feature_name           = "s3Import"
  role_arn               = module.rds_s3_import_role.iam_role_arn
}


