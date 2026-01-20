# RDS Cluster Module - Sample Usage

## main.tf
```terraform
module "rds" {
  source = "../../modules/rds-cluster"
  providers = {
    aws.primary   = aws
    aws.secondary = aws
  }

  region                      = var.region
  sec_region                  = var.sec_region
  primary_azs_name            = var.azs_name
  secondary_azs_name          = []
  primary_vpc_id              = module.network.vpc_id
  private_subnet_ids_p        = module.network.private_subnet_ids
  private_subnet_ids_s        = null
  name                        = var.name
  identifier                  = var.identifier
  engine                      = var.engine
  engine_version_pg           = var.engine_version_pg
  engine_version_mysql        = var.engine_version_mysql
  instance_class              = var.db_instance_class

  database_name               = "welfandb"
  username                    = "welfanuser"
  password                    = "password"
  manage_master_user_password = var.manage_master_user_password
  setup_globaldb              = var.setup_globaldb
  setup_as_secondary          = var.setup_as_secondary
  monitoring_interval         = var.monitoring_interval
  storage_encrypted           = var.storage_encrypted
  storage_type                = var.storage_type
  primary_instance_count      = var.primary_instance_count
  secondary_instance_count    = var.secondary_instance_count
  snapshot_identifier         = var.snapshot_identifier
}
```

## variables.tf
```terraform
variable "region" {
  type = string
}

variable "sec_region" {
  description = "The name of the secondary AWS region you wish to deploy into"
  type        = string
}

variable "azs_name" {
  type = list(string)
}

variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "aurora"
}

variable "identifier" {
  description = "Cluster identifier"
  type        = string
  default     = "aurora"
}

variable "engine" {
  description = "Aurora database engine type: aurora, aurora-mysql, aurora-postgresql"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version_pg" {
  description = "Aurora PostgreSQL database engine version."
  type        = string
}

variable "engine_version_mysql" {
  description = "Aurora MySQL database engine version."
  type        = string
}

variable "db_instance_class" {
  type        = string
  description = "Aurora DB Instance type. Specify db.serverless to create Aurora Serverless v2 instances."
}

variable "manage_master_user_password" {
  description = "Manage master user password using AWS Secrets Manager"
  type        = bool
  default     = false
}

variable "setup_globaldb" {
  description = "Setup Aurora Global Database with 1 Primary and 1 X-region Secondary cluster"
  type        = bool
  default     = false
}

variable "setup_as_secondary" {
  description = "Setup aws_rds_cluster.primary Terraform resource as Secondary Aurora cluster after an unplanned Aurora Global DB failover"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds"
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Valid values for var: monitoring_interval are (0, 1, 5, 10, 15, 30, 60)."
  }
}

variable "storage_encrypted" {
  description = "Specifies whether the underlying Aurora storage layer should be encrypted"
  type        = bool
  default     = false
}

variable "storage_type" {
  description = "Specifies Aurora storage type: Aurora Standard vs. Aurora I/O-Optimized"
  type        = string
  default     = ""
}

variable "primary_instance_count" {
  description = "Instance count for primary Aurora cluster"
  type        = number
  default     = 2
}

variable "secondary_instance_count" {
  description = "Instance count for secondary Aurora cluster"
  type        = number
  default     = 1
}

variable "snapshot_identifier" {
  description = "ID of snapshot to restore. If you do not want to restore a db, leave the default empty string."
  type        = string
  default     = ""
}
```

## terraform.tfvars
```hcl
region                      = "ap-northeast-1"
sec_region                  = null
azs_name                    = ["a", "c"]
identifier                  = "welfan-namecard-cluster"
name                        = "welfan-namecard"
engine                      = "aurora-postgresql"
engine_version_pg           = "16.4"
engine_version_mysql        = null
db_instance_class           = "db.t3.medium"
manage_master_user_password = false
setup_globaldb              = false
setup_as_secondary          = false
monitoring_interval         = 60
storage_encrypted           = true
storage_type                = ""
primary_instance_count      = 2
secondary_instance_count    = 0
snapshot_identifier         = ""
```

## Outputs
```terraform
# Access outputs:
module.rds.cluster_endpoint
module.rds.cluster_reader_endpoint
module.rds.cluster_arn
module.rds.cluster_identifier
```
