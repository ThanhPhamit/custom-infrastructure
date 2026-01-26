# RDS Unified Module - Sample Usage

## Tính năng chính

✅ Auto-generated password (Secrets Manager)  
✅ Read Replica (optional)  
✅ Enhanced Monitoring & Performance Insights  
✅ S3 Integration (PostgreSQL)  
✅ Custom Parameter Groups

---

## Example 1: Development

```terraform
module "rds" {
  source = "../../modules/rds-unified"

  app_name           = "myapp-dev"
  db_name            = "myapp-dev-db"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
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
  restricted_security_group_ids = [module.ecs.security_group_id]

  # Development settings
  deletion_protection          = false
  skip_final_snapshot          = true
  multi_az                     = false
  create_replica               = false
  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = { Environment = "development" }
}
```

---

## Example 2: Production PostgreSQL

```terraform
module "rds" {
  source = "../../modules/rds-unified"

  app_name           = "myapp-prod"
  db_name            = "myapp-prod-db"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
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
    module.ecs_web.security_group_id,
    module.ecs_api.security_group_id
  ]
  deletion_protection = true

  # Monitoring
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # Recommended PostgreSQL Parameters (auto-included)
  # - pg_stat_statements for query analysis
  # - UTF8 encoding
  # - Query tracking

  # S3 Integration (optional)
  enable_s3_integration = true
  s3_bucket_arns        = ["arn:aws:s3:::myapp-db-backups/*"]

  tags = { Environment = "production" }
}
```

---

## Recommended Parameter Group Settings

Module tự động cấu hình các parameters sau cho **PostgreSQL**:

| Parameter                   | Value                | Mục đích                   |
| --------------------------- | -------------------- | -------------------------- |
| `shared_preload_libraries`  | `pg_stat_statements` | Query performance analysis |
| `pg_stat_statements.track`  | `all`                | Track tất cả queries       |
| `pg_stat_statements.max`    | `10000`              | Số queries lưu trữ         |
| `track_activity_query_size` | `2048`               | Query text length          |
| `client_encoding`           | `UTF8`               | Character encoding         |

### Thêm Custom Parameters (nếu cần):

```terraform
custom_parameters = [
  # Slow query logging
  { name = "log_min_duration_statement", value = "1000" },  # Log queries > 1s

  # Connection tuning
  { name = "max_connections", value = "200" },

  # Memory tuning (cho instance lớn)
  { name = "shared_buffers", value = "{DBInstanceClassMemory/4}" },
  { name = "work_mem", value = "262144" },  # 256MB
]
```

### Dùng Default Parameter Group (Development only):

```terraform
create_parameter_group = false
parameter_group_name   = "default.postgres17"  # hoặc "default.mysql8.0"
```

---

## Outputs

```terraform
module.rds.db_endpoint          # hostname:port
module.rds.db_hostname          # hostname only
module.rds.db_port              # port
module.rds.db_name              # database name
module.rds.password_secret_arn  # Secrets Manager ARN
module.rds.security_group_id    # SG ID
module.rds.replica_endpoint     # Replica endpoint (if enabled)
```

---

## Get Password

```bash
aws secretsmanager get-secret-value \
  --secret-id "<password_secret_arn>" \
  --query 'SecretString' --output text
```
