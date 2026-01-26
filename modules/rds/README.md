# AWS RDS Unified Terraform Module

Terraform module which creates RDS database instances with optional read replicas.

## Features

This module supports creating:

- **RDS Instance** - PostgreSQL, MySQL, or MariaDB
- **Read Replica** - Optional cross-AZ replica
- **Subnet Group** - Database network configuration
- **Security Group** - Database access control
- **Parameter Group** - Custom database parameters
- **Secrets Manager** - Auto-generated password storage
- **Enhanced Monitoring** - CloudWatch metrics
- **Performance Insights** - Query analysis
- **S3 Integration** - PostgreSQL S3 export/import

## Usage

### Example 1: Development (Cost Optimized)

```terraform
module "rds" {
  source = "../../modules/rds"

  app_name           = "${var.environment}-${var.app_name}"
  db_name            = "${var.environment}-${var.app_name}-db"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnets
  availability_zone  = "ap-northeast-1a"

  # Database
  db_database = "myapp"
  db_username = "dbadmin"

  # Engine
  engine         = "postgres"
  engine_version = "17.2"
  engine_family  = "postgres17"
  instance_class = "db.t4g.micro"

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100

  # Security
  restricted_security_group_ids = [module.ecs_api.ecs_security_group_id]

  # Development settings
  deletion_protection          = false
  skip_final_snapshot          = true
  multi_az                     = false
  create_replica               = false
  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = {
    Environment = "development"
    Terraform   = "true"
  }
}
```

### Example 2: Production PostgreSQL

```terraform
module "rds" {
  source = "../../modules/rds"

  app_name           = "${var.environment}-${var.app_name}"
  db_name            = "${var.environment}-${var.app_name}-db"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnets
  availability_zone  = "ap-northeast-1a"

  # Database
  db_database = "production"
  db_username = "dbadmin"
  db_port     = 5432

  # Engine
  engine         = "postgres"
  engine_version = "17.2"
  engine_family  = "postgres17"
  instance_class = "db.r6g.large"

  # Storage
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp3"
  storage_encrypted     = true

  # High Availability
  multi_az                  = true
  create_replica            = true
  replica_availability_zone = "ap-northeast-1c"

  # Backup
  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "myapp-prod-db-final"

  # Security
  restricted_security_group_ids = [
    module.ecs_web.ecs_security_group_id,
    module.ecs_api.ecs_security_group_id
  ]
  deletion_protection = true

  # Monitoring
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # S3 Integration (optional)
  enable_s3_integration = true
  s3_bucket_arns        = ["arn:aws:s3:::myapp-db-backups/*"]

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: Using Existing Subnet Group

```terraform
module "rds" {
  source = "../../modules/rds"

  app_name          = "${var.environment}-${var.app_name}"
  db_name           = "${var.environment}-${var.app_name}-db"
  vpc_id            = module.network.vpc_id
  availability_zone = "ap-northeast-1a"

  # Use subnet group from network module
  db_subnet_group_name = module.network.database_subnet_group_name

  # ... other configuration ...
}
```

## Instance Class Recommendations

| Environment | Instance Class | vCPU | Memory | Use Case               |
| ----------- | -------------- | ---- | ------ | ---------------------- |
| Development | db.t4g.micro   | 2    | 1GB    | Testing, low traffic   |
| Staging     | db.t4g.small   | 2    | 2GB    | Light workloads        |
| Production  | db.r6g.large   | 2    | 16GB   | Production workloads   |
| Heavy       | db.r6g.xlarge  | 4    | 32GB   | High-performance needs |

## Storage Type Comparison

| Type | IOPS             | Cost   | Use Case                 |
| ---- | ---------------- | ------ | ------------------------ |
| gp2  | Burst up to 3000 | Low    | Development, testing     |
| gp3  | Configurable     | Medium | Production (recommended) |
| io1  | Provisioned      | High   | High-performance needs   |

## Recommended PostgreSQL Parameters

The module automatically configures these parameters:

| Parameter                   | Value                | Purpose                    |
| --------------------------- | -------------------- | -------------------------- |
| `shared_preload_libraries`  | `pg_stat_statements` | Query performance analysis |
| `pg_stat_statements.track`  | `all`                | Track all queries          |
| `pg_stat_statements.max`    | `10000`              | Stored query count         |
| `track_activity_query_size` | `2048`               | Query text length          |
| `client_encoding`           | `UTF8`               | Character encoding         |

## Inputs

| Name                          | Description                               | Type           | Default          | Required |
| ----------------------------- | ----------------------------------------- | -------------- | ---------------- | :------: |
| app_name                      | Application name for resource naming      | `string`       | n/a              |   yes    |
| db_name                       | Database identifier                       | `string`       | n/a              |   yes    |
| vpc_id                        | VPC ID                                    | `string`       | n/a              |   yes    |
| availability_zone             | Primary availability zone                 | `string`       | n/a              |   yes    |
| private_subnet_ids            | Subnet IDs for DB subnet group            | `list(string)` | `[]`             |   no\*   |
| db_subnet_group_name          | Existing DB subnet group name             | `string`       | `null`           |   no\*   |
| db_database                   | Database name                             | `string`       | `"main"`         |    no    |
| db_username                   | Master username                           | `string`       | `"dbadmin"`      |    no    |
| db_password                   | Master password (auto-generated if empty) | `string`       | `""`             |    no    |
| db_port                       | Database port                             | `number`       | `5432`           |    no    |
| engine                        | Database engine                           | `string`       | `"postgres"`     |    no    |
| engine_version                | Engine version                            | `string`       | `"17.2"`         |    no    |
| engine_family                 | Parameter group family                    | `string`       | `"postgres17"`   |    no    |
| instance_class                | Instance class                            | `string`       | `"db.t4g.micro"` |    no    |
| allocated_storage             | Initial storage (GB)                      | `number`       | `20`             |    no    |
| max_allocated_storage         | Max storage for autoscaling (GB)          | `number`       | `100`            |    no    |
| storage_type                  | Storage type (gp2, gp3, io1)              | `string`       | `"gp3"`          |    no    |
| storage_encrypted             | Enable encryption                         | `bool`         | `true`           |    no    |
| multi_az                      | Enable Multi-AZ                           | `bool`         | `false`          |    no    |
| create_replica                | Create read replica                       | `bool`         | `false`          |    no    |
| replica_availability_zone     | Replica AZ                                | `string`       | `null`           |    no    |
| backup_retention_period       | Backup retention (days)                   | `number`       | `35`             |    no    |
| skip_final_snapshot           | Skip final snapshot                       | `bool`         | `false`          |    no    |
| deletion_protection           | Enable deletion protection                | `bool`         | `true`           |    no    |
| restricted_security_group_ids | Allowed security groups                   | `list(string)` | `[]`             |    no    |
| monitoring_interval           | Enhanced monitoring interval              | `number`       | `0`              |    no    |
| performance_insights_enabled  | Enable Performance Insights               | `bool`         | `false`          |    no    |
| enable_s3_integration         | Enable S3 integration (PostgreSQL)        | `bool`         | `false`          |    no    |
| tags                          | Tags to apply to resources                | `map(string)`  | `{}`             |    no    |

\*Either `private_subnet_ids` or `db_subnet_group_name` must be provided

## Outputs

| Name                   | Description                   |
| ---------------------- | ----------------------------- |
| db_instance_id         | RDS instance ID               |
| db_instance_identifier | RDS instance identifier       |
| db_instance_arn        | RDS instance ARN              |
| db_endpoint            | Database endpoint (host:port) |
| db_hostname            | Database hostname             |
| db_port                | Database port                 |
| db_name                | Database name                 |
| db_username            | Master username               |
| replica_endpoint       | Replica endpoint (if created) |
| replica_hostname       | Replica hostname (if created) |
| security_group_id      | Security group ID             |
| secret_arn             | Secrets Manager secret ARN    |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
