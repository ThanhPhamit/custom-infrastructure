variable "app_name" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_database" {
  type    = string
  default = "main"
}

# variable "alb_security_group_id" {}
# variable "ecs_scheduler_security_group_id" {}
variable "vpc_id" {}
variable "private_subnet_ids" {}

# variable "aws_region" {}

# variable "azs_name" {}

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

variable "availability_zone" {}

variable "enabled_cloudwatch_logs_exports" {
  type    = list(string)
  default = ["postgresql", "upgrade"]
}

variable "replica_availability_zone" {}