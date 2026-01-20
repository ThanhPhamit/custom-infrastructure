# RDS Instance Module - Sample Usage

## main.tf
```terraform
module "rds_instance" {
  source = "../../modules/rds-instance"

  app_name                     = var.app_name
  db_name                      = var.db_name
  db_username                  = var.db_username
  db_password                  = var.db_password
  db_port                      = var.db_port
  db_database                  = var.db_database
  vpc_id                       = module.network.vpc_id
  private_subnet_ids           = module.network.private_subnet_ids
  
  engine                       = var.engine
  engine_version               = var.engine_version
  engine_family                = var.engine_family
  instance_class               = var.instance_class
  
  multi_az                     = var.multi_az
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  availability_zone            = var.availability_zone
  replica_availability_zone    = var.replica_availability_zone
  
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
}
```

## variables.tf
```terraform
variable "app_name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_database" {
  type    = string
  default = "main"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "17.2"
}

variable "engine_family" {
  type    = string
  default = "postgres17"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 800
}

variable "availability_zone" {
  type = string
}

variable "replica_availability_zone" {
  type = string
}

variable "enabled_cloudwatch_logs_exports" {
  type    = list(string)
  default = ["postgresql", "upgrade"]
}
```

## terraform.tfvars
```hcl
app_name                  = "welfan-namecard-staging"
db_name                   = "welfan-db-instance"
db_username               = "dbadmin"
db_password               = "SecurePassword123!"
db_port                   = 5432
db_database               = "main"
engine                    = "postgres"
engine_version            = "17.2"
engine_family             = "postgres17"
instance_class            = "db.t4g.micro"
multi_az                  = false
allocated_storage         = 20
max_allocated_storage     = 800
availability_zone         = "ap-northeast-1a"
replica_availability_zone = "ap-northeast-1c"
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
```

## Outputs
```terraform
# Access outputs:
module.rds_instance.endpoint
module.rds_instance.port
module.rds_instance.engine
module.rds_instance.db_instance_identifier
```
