terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
      configuration_aliases = [
        aws.primary,
        aws.secondary
      ]
    }
  }
}


#########################
# Create Unique password
#########################

resource "random_password" "master_password" {
  length  = 10
  special = false
}


####################################
# Generate Final snapshot identifier
####################################

resource "random_id" "snapshot_id" {

  keepers = {
    id = var.identifier
  }

  byte_length = 4
}

resource "aws_security_group" "primary-cluster" {
  name        = "${var.identifier}-sg"
  description = "security group for db"

  vpc_id = var.primary_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.identifier}-sg"
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


resource "aws_db_subnet_group" "private_p" {
  provider   = aws.primary
  name       = "${var.name}-sg"
  subnet_ids = var.private_subnet_ids_p
  tags = {
    Name = "${var.name}-sg"
  }
}

resource "aws_db_subnet_group" "private_s" {
  provider   = aws.secondary
  count      = var.setup_globaldb ? 1 : 0
  name       = "${var.name}-sg"
  subnet_ids = var.private_subnet_ids_s
  tags = {
    Name = "${var.name}-sg"
  }
}

###########
# KMS
###########

resource "aws_kms_key" "kms_p" {
  provider    = aws.primary
  count       = var.storage_encrypted || (!var.setup_globaldb && var.manage_master_user_password) ? 1 : 0
  description = "KMS key for Aurora Storage Encryption and master user Secrets Manager secret"
  # following causes terraform destroy to fail. But this is needed so that Aurora encrypted snapshots can be restored for your production workload.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_key" "kms_s" {
  provider    = aws.secondary
  count       = var.setup_globaldb && var.storage_encrypted ? 1 : 0
  description = "KMS key for Aurora Storage Encryption"
  # following causes terraform destroy to fail. But this is needed so that Aurora encrypted snapshots can be restored for your production workload.
  lifecycle {
    prevent_destroy = true
  }
}


module "rds_monitoring_role" {
  source     = "../iam_role"
  name       = "${var.name}-rds-monitoring-role"
  identifier = "monitoring.rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  }
}

#############################
# RDS Aurora Parameter Groups
##############################

resource "aws_rds_cluster_parameter_group" "aurora_cluster_parameter_group_p" {
  provider    = aws.primary
  name_prefix = "${var.name}-cluster-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-cluster-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_cluster_pgroup_params : local.mysql_cluster_pgroup_params
    iterator = pblock

    content {
      name         = pblock.value.name
      value        = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "aurora_db_parameter_group_p" {
  provider    = aws.primary
  name_prefix = "${var.name}-db-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-db-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_db_pgroup_params : local.mysql_db_pgroup_params
    iterator = pblock

    content {
      name         = pblock.value.name
      value        = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_parameter_group_s" {
  count       = var.setup_globaldb ? 1 : 0
  provider    = aws.secondary
  name_prefix = "${var.name}-cluster-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-cluster-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_cluster_pgroup_params : local.mysql_cluster_pgroup_params
    iterator = pblock

    content {
      name         = pblock.value.name
      value        = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "aurora_db_parameter_group_s" {
  count       = var.setup_globaldb ? 1 : 0
  provider    = aws.secondary
  name_prefix = "${var.name}-db-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-db-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_db_pgroup_params : local.mysql_db_pgroup_params
    iterator = pblock

    content {
      name         = pblock.value.name
      value        = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

#############
# RDS Aurora
#############

# Aurora Global DB 
resource "aws_rds_global_cluster" "globaldb" {
  count                     = var.setup_globaldb ? 1 : 0
  provider                  = aws.primary
  global_cluster_identifier = "${var.identifier}-globaldb"
  engine                    = (var.snapshot_identifier == "") ? var.engine : null
  engine_version            = (var.snapshot_identifier == "") ? (var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql) : null
  database_name             = (var.snapshot_identifier == "") ? var.database_name : null
  storage_encrypted         = var.storage_encrypted
  # Uncomment the following line for restoring cluster from snapshot. Conditionally specifying null for the argument still creating Terraform Cycle error.
  # source_db_cluster_identifier = (var.snapshot_identifier == "") ? null : aws_rds_cluster.primary.arn
  force_destroy = (var.snapshot_identifier == "") ? null : true

  lifecycle {
    ignore_changes = [source_db_cluster_identifier]
  }
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  global_cluster_identifier = var.setup_globaldb && (var.snapshot_identifier == "") ? aws_rds_global_cluster.globaldb[0].id : null

  cluster_identifier          = "${var.identifier}-${var.region}"
  engine                      = var.engine
  engine_version              = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  allow_major_version_upgrade = var.allow_major_version_upgrade
  # db_cluster_instance_class   = var.instance_class
  port          = var.port == "" ? var.engine == "aurora-postgresql" ? "5432" : "3306" : var.port
  database_name = var.setup_as_secondary || (var.snapshot_identifier != "") ? null : var.database_name

  # Aurora global DB currently doesn't support master password management with AWS Secrets Manager
  manage_master_user_password   = !var.setup_globaldb && var.manage_master_user_password ? var.manage_master_user_password : null
  master_user_secret_kms_key_id = !var.setup_globaldb && var.manage_master_user_password ? aws_kms_key.kms_p[0].arn : null
  master_username               = var.setup_as_secondary || (var.snapshot_identifier != "") ? null : var.username
  master_password               = (var.setup_as_secondary || (var.snapshot_identifier != "")) || (!var.setup_globaldb && var.manage_master_user_password) ? null : (var.password == "" ? random_password.master_password.result : var.password)

  db_cluster_parameter_group_name  = aws_rds_cluster_parameter_group.aurora_cluster_parameter_group_p.id
  db_instance_parameter_group_name = var.allow_major_version_upgrade ? aws_db_parameter_group.aurora_db_parameter_group_p.id : null

  storage_type = var.storage_type

  vpc_security_group_ids = [aws_security_group.primary-cluster.id]
  db_subnet_group_name   = aws_db_subnet_group.private_p.name

  availability_zones = [for az in var.primary_azs_name : "${var.region}${az}"]

  storage_encrypted         = var.storage_encrypted
  kms_key_id                = var.storage_encrypted ? aws_kms_key.kms_p[0].arn : null
  deletion_protection       = false
  copy_tags_to_snapshot     = true
  apply_immediately         = true
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.identifier}-${var.region}-${random_id.snapshot_id.hex}"
  snapshot_identifier       = var.snapshot_identifier != "" ? var.snapshot_identifier : null

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window

  enabled_cloudwatch_logs_exports = local.logs_set

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  iam_database_authentication_enabled = true

  tags = {
    Name = "${var.identifier}-${var.region}"
  }


  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.instance_class == "db.serverless" ? [local.serverlessv2_scaling_configuration] : []

    content {
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
    }
  }

  depends_on = [
    # When this Aurora cluster is setup as a secondary, setting up the dependency makes sure to delete this cluster 1st before deleting current primary Cluster during terraform destroy
    # Comment out the following line if this cluster has changed role to be the primary Aurora cluster because of a failover for terraform destroy to work
    # aws_rds_cluster_instance.secondary,
  ]

  lifecycle {
    ignore_changes = [
      replication_source_identifier,
      global_cluster_identifier,
      snapshot_identifier,
      # Since Terraform doesn't allow to conditionally specify a lifecycle policy, this can't be done dynamically.
      # Uncomment the following line for Aurora Global Database to do major version upgrade as per https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster
      # engine_version,
    ]
  }
}
resource "aws_rds_cluster_instance" "primary" {
  count                        = var.primary_instance_count
  identifier                   = "${var.name}-${var.region}-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.primary.id
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  auto_minor_version_upgrade   = var.setup_globaldb ? false : var.auto_minor_version_upgrade
  instance_class               = var.instance_class
  db_subnet_group_name         = aws_db_subnet_group.private_p.name
  db_parameter_group_name      = aws_db_parameter_group.aurora_db_parameter_group_p.id
  performance_insights_enabled = true
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = module.rds_monitoring_role.iam_role_arn
  apply_immediately            = true
}

# Secondary Aurora Cluster
resource "aws_rds_cluster" "secondary" {
  count                            = var.setup_globaldb ? 1 : 0
  provider                         = aws.secondary
  global_cluster_identifier        = aws_rds_global_cluster.globaldb[0].id
  cluster_identifier               = "${var.identifier}-${var.sec_region}"
  engine                           = var.engine
  engine_version                   = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  allow_major_version_upgrade      = var.allow_major_version_upgrade
  availability_zones               = [for az in var.secondary_azs_name : "${var.sec_region}${az}"]
  db_subnet_group_name             = aws_db_subnet_group.private_s[0].name
  port                             = var.port == "" ? var.engine == "aurora-postgresql" ? "5432" : "3306" : var.port
  db_cluster_parameter_group_name  = aws_rds_cluster_parameter_group.aurora_cluster_parameter_group_s[0].id
  db_instance_parameter_group_name = var.allow_major_version_upgrade ? aws_db_parameter_group.aurora_db_parameter_group_s[0].id : null
  backup_retention_period          = var.backup_retention_period
  preferred_backup_window          = var.preferred_backup_window
  source_region                    = var.storage_encrypted ? var.region : null
  kms_key_id                       = var.storage_encrypted ? aws_kms_key.kms_s[0].arn : null
  storage_type                     = var.storage_type
  apply_immediately                = true
  skip_final_snapshot              = var.skip_final_snapshot
  final_snapshot_identifier        = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.identifier}-${var.sec_region}-${random_id.snapshot_id.hex}"
  enabled_cloudwatch_logs_exports  = local.logs_set

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.instance_class == "db.serverless" ? [local.serverlessv2_scaling_configuration] : []

    content {
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
    }
  }

  depends_on = [
    # When this Aurora cluster is setup as a secondary, setting up the dependency makes sure to delete this cluster 1st before deleting current primary Cluster during terraform destroy
    # Comment out the following line if this cluster has changed role to be the primary Aurora cluster because of a failover for terraform destroy to work
    aws_rds_cluster_instance.primary,
  ]

  lifecycle {
    ignore_changes = [
      replication_source_identifier,
      global_cluster_identifier,
      # Since Terraform doesn't allow to conditionally specify a lifecycle policy, this can't be done dynamically.
      # Uncomment the following line for Aurora Global Database to do major version upgrade as per https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster
      # engine_version,
    ]
  }
}

# Secondary Cluster Instances
#tfsec:ignore:aws-rds-enable-performance-insights-encryption tfsec:ignore:aws-rds-enable-performance-insights
resource "aws_rds_cluster_instance" "secondary" {
  count                        = var.setup_globaldb ? var.secondary_instance_count : 0
  provider                     = aws.secondary
  identifier                   = "${var.name}-${var.sec_region}-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.secondary[0].id
  engine                       = var.engine
  engine_version               = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  auto_minor_version_upgrade   = false
  instance_class               = var.instance_class
  db_subnet_group_name         = aws_db_subnet_group.private_s[0].name
  db_parameter_group_name      = aws_db_parameter_group.aurora_db_parameter_group_s[0].id
  performance_insights_enabled = true
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = module.rds_monitoring_role.iam_role_arn
  apply_immediately            = true
}

# dump 作成の必要が出たときのために
# postgres の s3 import export を有効にしておく
resource "aws_iam_policy" "rds_s3_integration" {
  name   = "${var.identifier}-rds-s3-integration-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.rds_s3_integration.json
}

module "rds_s3_export_role" {
  source     = "../iam_role"
  name       = "${var.identifier}-rds-s3-export-role"
  identifier = "rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = aws_iam_policy.rds_s3_integration.arn
  }
}

module "rds_s3_import_role" {
  source     = "../iam_role"
  name       = "${var.identifier}-rds-s3-import-role"
  identifier = "rds.amazonaws.com"
  policy_arns_map = {
    "policy_1" = aws_iam_policy.rds_s3_integration.arn
  }
}

resource "aws_rds_cluster_role_association" "db_export" {
  db_cluster_identifier = aws_rds_cluster.primary.id
  feature_name          = "s3Export"
  role_arn              = module.rds_s3_export_role.iam_role_arn
}

resource "aws_rds_cluster_role_association" "db_import" {
  db_cluster_identifier = aws_rds_cluster.primary.id
  feature_name          = "s3Import"
  role_arn              = module.rds_s3_import_role.iam_role_arn
}

# TODO: Setup IAM role for IamDatabaseAuthentication

# PROXY
# # Create a security group for the RDS Proxy
# resource "aws_security_group" "proxy_sg" {
#   name = "rds_proxy_sg"
#   vpc_id = aws_vpc.main.id

#   # Allow inbound traffic on port 3306 (MySQL) from the App Server's security group
#   ingress {
#     from_port = 3306
#     to_port = 3306
#     protocol = "tcp"
#     # Replace with the actual security group ID of your App Server
#     security_groups = ["sg-your_app_server_sg_id"] 
#   }

#   # Allow outbound traffic to the RDS instances
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # IAM Role for RDS Proxy
# resource "aws_iam_role" "proxy_role" {
#   name = "rds_proxy_role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "rds.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF
# }

# # Attach necessary policies to the role
# resource "aws_iam_role_policy_attachment" "proxy_policy_attachment" {
#   role       = aws_iam_role.proxy_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDBProxyFullAccess"
# }

# # Create the RDS Proxy
# resource "aws_db_proxy" "example" {
#   name                   = "rds_proxy"
#   debug_logging          = false
#   engine_family          = var.engine_family
#   idle_client_timeout    = 1800
#   require_tls            = true
#   role_arn               = aws_iam_role.proxy_role.arn
#   vpc_security_group_ids = [aws_security_group.proxy_sg.id]
#   vpc_subnet_ids         = var.private_subnet_ids

#   auth {
#     auth_scheme = "SECRETS"
#     secret_arn  = aws_secretsmanager_secret.example.arn
#   }

# }

# resource "aws_db_proxy_default_target_group" "example" {
#   db_proxy_name = aws_db_proxy.example.name

#   connection_pool_config {
#     connection_borrow_timeout    = 120
#     init_query                   = "SET x=1, y=2"
#     max_connections_percent      = 100
#     max_idle_connections_percent = 50
#     session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
#   }
# }


# # Create a Secrets Manager secret for RDS Proxy authentication
# resource "aws_secretsmanager_secret" "example" {
#   name = "rds_proxy_secret"
# }

# # Store the master database credentials in the secret
# resource "aws_secretsmanager_secret_version" "example" {
#   secret_id = aws_secretsmanager_secret.example.id
#   secret_string = <<EOF
# {
#   "username": "admin", # Replace with your master username
#   "password": "password"  # Replace with your master password
# }
# EOF
# }

# # Add the RDS instances (master and read-only) as targets to the proxy
# resource "aws_db_proxy_target" "master_target" {
#   db_proxy_name          = aws_db_proxy.example.name
#   target_group_name     = "default"
#   db_instance_identifier = aws_db_instance.master.id
# }

# resource "aws_db_proxy_target" "read_replica_target" {
#   db_proxy_name          = aws_db_proxy.example.name
#   target_group_name     = "default"
#   db_instance_identifier = aws_db_instance.read_replica.id
# }


# resource "aws_security_group" "allow_all" {
#   name = "allow_all"
#   vpc_id = aws_vpc.main.id

#   ingress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
