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

resource "aws_security_group_rule" "db" {
  count = length(var.restricted_security_group_ids)

  security_group_id        = aws_security_group.db.id
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = var.restricted_security_group_ids[count.index]
  type                     = "ingress"
}

# Password for RDS is randomly generated and stored in AWS Secrets Manager
resource "random_password" "rds" {
  length  = 20
  special = true
}

resource "random_uuid" "rds_secret_uuid" {}

resource "aws_secretsmanager_secret" "rds_password" {
  name        = "${var.app_name}-rds-password-${substr(random_uuid.rds_secret_uuid.result, 0, 2)}"
  description = "RDS master password for ${var.app_name}-rds"
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = random_password.rds.result
}

resource "aws_db_subnet_group" "db" {
  name        = "${var.app_name}-db-subnet-group"
  description = "db subnet group for ${var.db_name}"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-db-subnet-group"
    }
  )
}

module "rds_monitoring_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-rds-monitoring-role"
  identifier = "monitoring.rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  }
}

resource "aws_db_instance" "db" {
  identifier = "${var.app_name}-rds-${var.engine}"

  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  parameter_group_name = var.parameter_group_name

  db_name  = var.db_database
  username = var.db_username
  password = random_password.rds.result
  port     = var.db_port

  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.db.name

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  max_allocated_storage           = var.max_allocated_storage
  multi_az                        = var.multi_az
  availability_zone               = var.availability_zone

  deletion_protection   = true
  copy_tags_to_snapshot = true

  backup_retention_period  = 35
  backup_window            = "20:57-21:27"
  delete_automated_backups = false

  performance_insights_enabled          = false
  performance_insights_retention_period = 0

  monitoring_interval = 60
  monitoring_role_arn = module.rds_monitoring_role.iam_role_arn

  apply_immediately = false
}
