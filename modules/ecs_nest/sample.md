# Network Module - Sample Usage

## main.tf

```terraform
module "ecs_nest" {
  source = "../modules/ecs_nest"

  region                 = var.region
  app_name               = "${var.environment}-${var.app_name}-nest"
  vpc_id                 = data.aws_vpc.this.id
  subnet_ids             = [for subnet in data.aws_subnet.private_subnets : subnet.id]
  load_balancer_type     = "nlb"
  nlb_arn                = module.elb_nest.nlb_arn
  acm_certificate_arn    = module.internal_acm.certificate_arn
  http_prod_listener_arn = null # Not used when load_balancer_type is "nlb"
  http_test_listener_arn = null # Not used when load_balancer_type is "nlb"
  alb_security_group_id  = module.elb_nest.nlb_security_group_id

  cluster_name    = module.ecs_cluster_nest.cluster_name
  container_names = var.ecs_nest_container_names
  container_port  = var.ecs_nest_port

  desired_task_count = var.ecs_nest_min_tasks
  task_cpu_size      = var.ecs_nest_task_cpu_size
  task_memory_size   = var.ecs_nest_task_memory_size

  repository_url        = module.ecr_private_registry_nest.repository_url
  repository_arn        = module.ecr_private_registry_nest.repository_arn
  app_health_check_path = var.ecs_nest_app_health_check_path

  # Container environment variables
  db_host     = var.ecs_nest_db_host
  db_port     = var.ecs_nest_db_port
  db_user     = var.ecs_nest_db_user
  db_password = var.ecs_nest_db_password
  db_name     = var.ecs_nest_db_name
  db_schema   = var.ecs_nest_db_schema
  db_timezone = var.ecs_nest_db_timezone

  white_list = "https://${var.elb_nuxt_alb_domain}"

  jwt_algorithm            = var.ecs_nest_jwt_algorithm
  jwt_expires_in           = var.ecs_nest_jwt_expires_in
  refresh_token_expires_in = var.ecs_nest_refresh_token_expires_in
  crypto_algorithm         = var.ecs_nest_crypto_algorithm

  redis_url = "redis://${module.elasticache_server_based.primary_endpoint_address}:${module.elasticache_server_based.primary_endpoint_port}"

  http_timeout       = var.ecs_nest_http_timeout
  http_max_redirects = var.ecs_nest_http_max_redirects

  wcs_robot_api_url        = var.ecs_nest_wcs_robot_api_url
  wcs_max_robot_call_queue = var.ecs_nest_wcs_max_robot_call_queue

  queue_host = module.elasticache_server_based.primary_endpoint_address
  queue_port = module.elasticache_server_based.primary_endpoint_port

  elasticache_security_group_id     = module.elasticache_server_based.security_group_id
  elasticache_primary_endpoint_port = module.elasticache_server_based.primary_endpoint_port
  tags                              = local.tags
}
```

## variables.tf

```terraform
variable "ecs_nest_min_tasks" {
  type        = number
  description = "Minimum number of tasks to run"
}

variable "ecs_nest_max_tasks" {
  type        = number
  description = "Maximum number of tasks to run (Auto Scaling)"
}

variable "ecs_nest_task_cpu_size" {
  type    = number
  default = 256
}

variable "ecs_nest_task_memory_size" {
  type    = number
  default = 512
}
variable "ecs_nest_container_names" {
  type        = list(string)
  description = "Names of the containers to run in the task"
}
variable "ecs_nest_app_health_check_path" {}
variable "ecs_nest_port" {}

# Environment variables
```

## terraform.tfvars

```hcl
ecs_nest_min_tasks             = 1
ecs_nest_max_tasks             = 3
ecs_nest_task_cpu_size         = 256
ecs_nest_task_memory_size      = 512
ecs_nest_container_names       = ["server"]
ecs_nest_app_health_check_path = "/health"
ecs_nest_port                  = 3000
# Environment variables for ECS Nest
```

## Outputs

```terraform

```
