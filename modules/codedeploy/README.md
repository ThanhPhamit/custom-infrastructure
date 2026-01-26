# AWS CodeDeploy for ECS Terraform Module

Terraform module which creates CodeDeploy application and deployment group for ECS Blue/Green deployments.

## Features

This module supports creating:

- **CodeDeploy Application** - ECS compute platform application
- **Deployment Group** - Blue/Green deployment configuration
- **S3 Bucket** - Revision storage for AppSpec files
- **IAM Role** - CodeDeploy service role
- **Deployment Scripts** - Auto-generated deployment scripts

## Usage

### Example 1: Basic CodeDeploy for ECS

```terraform
module "codedeploy_ecs" {
  source = "../../modules/codedeploy"

  aws_region                 = var.region
  app_name                   = "${var.environment}-${var.app_name}-ecs-api"
  ecs_cluster_name           = module.ecs_cluster.cluster_name
  ecs_service_name           = module.ecs_api.service_name
  lb_listener_prod_arn       = module.alb.lb_listener_http_prod_arn
  lb_listener_test_arn       = module.alb.lb_listener_http_test_arn
  lb_target_group_blue_name  = module.ecs_api.lb_target_group_blue_name
  lb_target_group_green_name = module.ecs_api.lb_target_group_green_name
  task_definition_arn        = module.ecs_api.task_definition_arn
  container_name             = "api"
  container_port             = 3000

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: CodeDeploy with NLB

```terraform
module "codedeploy_ecs_nest" {
  source = "../../modules/codedeploy"

  aws_region                 = var.region
  app_name                   = "${var.environment}-${var.app_name}-ecs-nest"
  ecs_cluster_name           = module.ecs_cluster.cluster_name
  ecs_service_name           = module.ecs_nest.service_name
  lb_listener_prod_arn       = module.ecs_nest.lb_listener_tcp_prod_arn
  lb_listener_test_arn       = module.ecs_nest.lb_listener_tcp_test_arn
  lb_target_group_blue_name  = module.ecs_nest.lb_target_group_blue_name
  lb_target_group_green_name = module.ecs_nest.lb_target_group_green_name
  task_definition_arn        = module.ecs_nest.task_definition_arn
  container_name             = var.ecs_nest_container_names[0]
  container_port             = var.ecs_nest_port

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: Custom Deployment Configuration

```terraform
module "codedeploy_ecs" {
  source = "../../modules/codedeploy"

  aws_region                 = var.region
  app_name                   = "${var.environment}-${var.app_name}-ecs-api"
  ecs_cluster_name           = module.ecs_cluster.cluster_name
  ecs_service_name           = module.ecs_api.service_name
  lb_listener_prod_arn       = module.alb.lb_listener_http_prod_arn
  lb_listener_test_arn       = module.alb.lb_listener_http_test_arn
  lb_target_group_blue_name  = module.ecs_api.lb_target_group_blue_name
  lb_target_group_green_name = module.ecs_api.lb_target_group_green_name
  task_definition_arn        = module.ecs_api.task_definition_arn
  container_name             = "api"
  container_port             = 3000

  # Custom deployment config
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## Deployment Configuration Options

| Configuration Name                                  | Description                           |
| --------------------------------------------------- | ------------------------------------- |
| `CodeDeployDefault.ECSAllAtOnce`                    | Deploy to all at once (fastest)       |
| `CodeDeployDefault.ECSLinear10PercentEvery1Minutes` | 10% every 1 minute                    |
| `CodeDeployDefault.ECSLinear10PercentEvery3Minutes` | 10% every 3 minutes                   |
| `CodeDeployDefault.ECSCanary10Percent5Minutes`      | 10% first, then remaining after 5min  |
| `CodeDeployDefault.ECSCanary10Percent15Minutes`     | 10% first, then remaining after 15min |

## Blue/Green Deployment Flow

```
1. Upload new AppSpec to S3
2. CodeDeploy creates new (Green) target group
3. New ECS tasks start in Green target group
4. Health check passes
5. Traffic shifts from Blue to Green
6. Blue target group drains connections
7. Blue tasks terminate
```

## GitHub Actions Integration

```yaml
- name: Deploy to ECS
  run: |
    aws deploy create-deployment \
      --application-name ${{ env.APP_NAME }} \
      --deployment-group-name ${{ env.APP_NAME }}-dg \
      --s3-location bucket=${{ env.S3_BUCKET }},key=appspec.yaml,bundleType=yaml
```

## Inputs

| Name                       | Description                          | Type          | Default                            | Required |
| -------------------------- | ------------------------------------ | ------------- | ---------------------------------- | :------: |
| aws_region                 | AWS region                           | `string`      | n/a                                |   yes    |
| app_name                   | Application name for resource naming | `string`      | n/a                                |   yes    |
| ecs_cluster_name           | ECS cluster name                     | `string`      | n/a                                |   yes    |
| ecs_service_name           | ECS service name                     | `string`      | n/a                                |   yes    |
| lb_listener_prod_arn       | Production listener ARN              | `string`      | n/a                                |   yes    |
| lb_listener_test_arn       | Test listener ARN                    | `string`      | n/a                                |   yes    |
| lb_target_group_blue_name  | Blue target group name               | `string`      | n/a                                |   yes    |
| lb_target_group_green_name | Green target group name              | `string`      | n/a                                |   yes    |
| task_definition_arn        | ECS task definition ARN              | `string`      | n/a                                |   yes    |
| container_name             | Container name in task definition    | `string`      | n/a                                |   yes    |
| container_port             | Container port number                | `number`      | n/a                                |   yes    |
| deployment_config_name     | CodeDeploy deployment config name    | `string`      | `"CodeDeployDefault.ECSAllAtOnce"` |    no    |
| revision_appspec_key       | S3 key for AppSpec file              | `string`      | `"appspec.yaml"`                   |    no    |
| revision_bundle_type       | Revision bundle type                 | `string`      | `"yaml"`                           |    no    |
| tags                       | Tags to apply to resources           | `map(string)` | `{}`                               |    no    |

## Outputs

| Name                     | Description                             |
| ------------------------ | --------------------------------------- |
| s3_bucket_name           | S3 bucket name for CodeDeploy revisions |
| create_deployment_script | Generated deployment script             |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
