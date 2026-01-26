# AWS ECS Service (NestJS/General) Terraform Module

Terraform module which creates an ECS Fargate service with Blue/Green deployment support.

## Features

This module supports creating:

- **ECS Service** - Fargate service with rolling/blue-green deployment
- **Task Definition** - Container configuration with environment variables
- **Target Groups** - Blue and Green target groups for deployment
- **Security Group** - Service network access control
- **CloudWatch Log Group** - Container logging
- **IAM Roles** - Task role and execution role
- **Auto Scaling** - Application auto scaling support
- **ALB/NLB Integration** - Support for both load balancer types

## Usage

### Example 1: ECS Service with ALB

```terraform
module "ecs_api" {
  source = "../../modules/ecs_nest"

  region                 = var.region
  app_name               = "${var.environment}-${var.app_name}-api"
  vpc_id                 = module.network.vpc_id
  subnet_ids             = module.network.private_subnets

  # ALB Configuration
  load_balancer_type     = "alb"
  http_prod_listener_arn = module.alb.lb_listener_http_prod_arn
  http_test_listener_arn = module.alb.lb_listener_http_test_arn
  alb_security_group_id  = module.alb.alb_security_group_id

  cluster_name    = module.ecs_cluster.cluster_name
  container_names = ["api"]
  container_port  = 3000

  desired_task_count = 2
  task_cpu_size      = 256
  task_memory_size   = 512

  repository_url        = module.ecr.repository_url
  repository_arn        = module.ecr.repository_arn
  app_health_check_path = "/health"

  # Database configuration
  db_host     = module.rds.db_hostname
  db_port     = module.rds.db_port
  db_user     = var.db_user
  db_password = var.db_password
  db_name     = var.db_name
  db_schema   = var.db_schema
  db_timezone = "Asia/Tokyo"

  # Application configuration
  white_list               = "https://${var.frontend_domain}"
  jwt_algorithm            = "HS256"
  jwt_expires_in           = "1d"
  refresh_token_expires_in = "7d"
  crypto_algorithm         = "aes-256-cbc"

  # Redis configuration
  redis_url  = "redis://${module.elasticache.primary_endpoint_address}:6379"
  queue_host = module.elasticache.primary_endpoint_address
  queue_port = 6379

  # HTTP client configuration
  http_timeout       = 30000
  http_max_redirects = 5

  # External API configuration
  wcs_robot_api_url        = var.wcs_robot_api_url
  wcs_max_robot_call_queue = 10

  # Security group for ElastiCache access
  elasticache_security_group_id     = module.elasticache.security_group_id
  elasticache_primary_endpoint_port = 6379

  tags = local.tags
}
```

### Example 2: ECS Service with NLB

```terraform
module "ecs_nest" {
  source = "../../modules/ecs_nest"

  region                 = var.region
  app_name               = "${var.environment}-${var.app_name}-nest"
  vpc_id                 = module.network.vpc_id
  subnet_ids             = module.network.private_subnets

  # NLB Configuration
  load_balancer_type     = "nlb"
  nlb_arn                = module.nlb.nlb_arn
  acm_certificate_arn    = module.internal_acm.certificate_arn
  http_prod_listener_arn = null  # Not used for NLB
  http_test_listener_arn = null  # Not used for NLB
  alb_security_group_id  = module.nlb.nlb_security_group_id

  cluster_name    = module.ecs_cluster.cluster_name
  container_names = var.ecs_nest_container_names
  container_port  = var.ecs_nest_port

  desired_task_count = var.ecs_nest_min_tasks
  task_cpu_size      = var.ecs_nest_task_cpu_size
  task_memory_size   = var.ecs_nest_task_memory_size

  repository_url        = module.ecr_nest.repository_url
  repository_arn        = module.ecr_nest.repository_arn
  app_health_check_path = "/health"

  # ... environment variables ...

  tags = local.tags
}
```

## Load Balancer Type Options

| Option                       | Description               | Use Case                  |
| ---------------------------- | ------------------------- | ------------------------- |
| `load_balancer_type = "alb"` | Application Load Balancer | HTTP/HTTPS, path routing  |
| `load_balancer_type = "nlb"` | Network Load Balancer     | TCP/TLS, high performance |

## Task Size Recommendations

| Workload    | CPU  | Memory | Use Case                    |
| ----------- | ---- | ------ | --------------------------- |
| Lightweight | 256  | 512MB  | Simple APIs, microservices  |
| Standard    | 512  | 1024MB | Web applications            |
| Medium      | 1024 | 2048MB | Data processing             |
| Heavy       | 2048 | 4096MB | ML inference, heavy compute |

## Inputs

| Name                              | Description                          | Type           | Default | Required |
| --------------------------------- | ------------------------------------ | -------------- | ------- | :------: |
| app_name                          | Application name for resource naming | `string`       | n/a     |   yes    |
| region                            | AWS region                           | `string`       | n/a     |   yes    |
| vpc_id                            | VPC ID                               | `string`       | n/a     |   yes    |
| subnet_ids                        | Private subnet IDs for tasks         | `list(string)` | n/a     |   yes    |
| cluster_name                      | ECS cluster name                     | `string`       | n/a     |   yes    |
| container_names                   | Container names in task              | `list(string)` | n/a     |   yes    |
| container_port                    | Container port number                | `number`       | n/a     |   yes    |
| repository_url                    | ECR repository URL                   | `string`       | n/a     |   yes    |
| repository_arn                    | ECR repository ARN                   | `string`       | n/a     |   yes    |
| app_health_check_path             | Health check path                    | `string`       | n/a     |   yes    |
| load_balancer_type                | Load balancer type (alb/nlb)         | `string`       | `"alb"` |    no    |
| http_prod_listener_arn            | Production listener ARN (ALB)        | `string`       | n/a     |  yes\*   |
| http_test_listener_arn            | Test listener ARN (ALB)              | `string`       | n/a     |  yes\*   |
| nlb_arn                           | NLB ARN (for NLB type)               | `string`       | `null`  |    no    |
| acm_certificate_arn               | ACM cert ARN (for NLB TLS)           | `string`       | `null`  |    no    |
| alb_security_group_id             | Load balancer security group ID      | `string`       | n/a     |   yes    |
| desired_task_count                | Desired number of tasks              | `number`       | n/a     |   yes    |
| task_cpu_size                     | Task CPU units                       | `number`       | n/a     |   yes    |
| task_memory_size                  | Task memory (MB)                     | `number`       | n/a     |   yes    |
| db_host                           | Database host                        | `string`       | n/a     |   yes    |
| db_port                           | Database port                        | `number`       | n/a     |   yes    |
| db_user                           | Database user                        | `string`       | n/a     |   yes    |
| db_password                       | Database password                    | `string`       | n/a     |   yes    |
| db_name                           | Database name                        | `string`       | n/a     |   yes    |
| elasticache_security_group_id     | ElastiCache security group ID        | `string`       | n/a     |   yes    |
| elasticache_primary_endpoint_port | ElastiCache port                     | `number`       | n/a     |   yes    |
| tags                              | Tags to apply to resources           | `map(string)`  | `{}`    |    no    |

\*Required when `load_balancer_type = "alb"`

## Outputs

| Name                             | Description                   |
| -------------------------------- | ----------------------------- |
| service_name                     | ECS service name              |
| lb_target_group_blue_name        | Blue target group name        |
| lb_target_group_blue_arn_suffix  | Blue target group ARN suffix  |
| lb_target_group_green_name       | Green target group name       |
| lb_target_group_green_arn_suffix | Green target group ARN suffix |
| task_definition_arn              | Task definition ARN           |
| task_definition_family           | Task definition family        |
| task_definition_revision         | Task definition revision      |
| ecs_task_role_arn                | ECS task role ARN             |
| ecs_task_execution_role_arn      | ECS task execution role ARN   |
| ecs_cloudwatch_log_group_name    | CloudWatch log group name     |
| ecs_security_group_id            | ECS service security group ID |
| lb_listener_tcp_prod_arn         | Production listener ARN (NLB) |
| lb_listener_tcp_test_arn         | Test listener ARN (NLB)       |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
