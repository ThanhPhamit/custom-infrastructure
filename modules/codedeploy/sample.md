# Network Module - Sample Usage

## main.tf

```terraform
module "codedeploy_ecs_nest" {
  source = "../modules/codedeploy"

  aws_region                 = var.region
  app_name                   = "${var.environment}-${var.app_name}-ecs-nest"
  ecs_cluster_name           = module.ecs_cluster_nest.cluster_name
  ecs_service_name           = module.ecs_nest.service_name
  lb_listener_prod_arn       = module.ecs_nest.lb_listener_tcp_prod_arn
  lb_listener_test_arn       = module.ecs_nest.lb_listener_tcp_test_arn
  lb_target_group_blue_name  = module.ecs_nest.lb_target_group_blue_name
  lb_target_group_green_name = module.ecs_nest.lb_target_group_green_name
  task_definition_arn        = module.ecs_nest.task_definition_arn
  container_name             = var.ecs_nest_container_names[0]
  container_port             = var.ecs_nest_port

  tags = local.tags
}
```

## variables.tf

```terraform

```

## terraform.tfvars

```hcl

```

## Outputs

```terraform

```
