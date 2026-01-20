# RDS Instance Module - Sample Usage

## main.tf

```terraform
module "rds" {
  source = "../modules/rds"

  app_name = "${var.environment}-${var.app_name}"

  db_name     = var.db_name
  db_username = var.db_username
  db_port     = var.db_port
  db_database = var.db_name

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  availability_zone  = "${var.region}${var.azs_name[0]}"
  multi_az           = var.db_multi_az

  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  parameter_group_name = var.parameter_group_name

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2

  # TODO: Monitoring
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  restricted_security_group_ids = [
    module.ecs_client.ecs_security_group_id,
    module.ecs_admin.ecs_security_group_id,
    # module.bastion_host.bastion_security_group_id
  ]

  tags = local.tags
}
```

## variables.tf

```terraform
variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
variable "parameter_group_name" {
  type = string
}
variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "focuson"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = false
}

# Bastion Host Module
variable "bastion_ami_id" {
  description = "AMI ID for the bastion host EC2 instance"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_pair_name" {
  description = "Name of the EC2 Key Pair for bastion host SSH access"
  type        = string
}

variable "create_bastion_eip" {
  description = "Whether to create an Elastic IP for the bastion host"
  type        = bool
  default     = true
}
variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the bastion host"
  type        = list(string)
}
```

## terraform.tfvars

```hcl
db_engine            = "mysql"
db_engine_version    = "8.0"
db_instance_class    = "db.t3.small"
parameter_group_name = "default.mysql8.0"
db_allocated_storage = 20
db_name              = "focuson"
db_username          = "admin"
db_port              = 3306
db_multi_az          = false
```

## Outputs

```terraform
# Access outputs:
```
