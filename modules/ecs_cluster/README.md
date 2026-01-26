# AWS ECS Cluster Terraform Module

Terraform module which creates an ECS cluster on AWS.

## Features

This module supports creating:

- **ECS Cluster** - Fargate-compatible ECS cluster
- **Container Insights** - CloudWatch Container Insights monitoring
- **Capacity Providers** - Fargate and Fargate Spot support

## Usage

### Example 1: Basic ECS Cluster

```terraform
module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Multiple Clusters for Different Services

```terraform
# Cluster for web frontend
module "ecs_cluster_web" {
  source = "../../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}-web"
  tags     = local.tags
}

# Cluster for API backend
module "ecs_cluster_api" {
  source = "../../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}-api"
  tags     = local.tags
}

# Cluster for background workers
module "ecs_cluster_worker" {
  source = "../../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}-worker"
  tags     = local.tags
}
```

### Example 3: Using with ECS Service

```terraform
module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}"
  tags     = local.tags
}

module "ecs_api" {
  source = "../../modules/ecs_nest"

  # ... other configuration ...

  cluster_name = module.ecs_cluster.cluster_name

  # ... more configuration ...
}
```

## Cluster Architecture

```
ECS Cluster
├── Capacity Providers
│   ├── FARGATE (default)
│   └── FARGATE_SPOT (optional)
├── Container Insights (enabled)
└── Services
    ├── Service A (Fargate)
    ├── Service B (Fargate)
    └── Service C (Fargate Spot)
```

## Cluster Organization Strategies

### Strategy 1: Single Cluster, Multiple Services

```terraform
module "ecs_cluster" {
  source   = "../../modules/ecs_cluster"
  app_name = "${var.environment}-${var.app_name}"
}

# All services in one cluster
module "ecs_web" {
  cluster_name = module.ecs_cluster.cluster_name
  # ...
}

module "ecs_api" {
  cluster_name = module.ecs_cluster.cluster_name
  # ...
}
```

**Pros:** Simpler management, shared resources
**Cons:** Less isolation between services

### Strategy 2: Cluster per Service Type

```terraform
module "ecs_cluster_frontend" {
  source   = "../../modules/ecs_cluster"
  app_name = "${var.environment}-frontend"
}

module "ecs_cluster_backend" {
  source   = "../../modules/ecs_cluster"
  app_name = "${var.environment}-backend"
}
```

**Pros:** Better isolation, independent scaling
**Cons:** More management overhead

## Inputs

| Name     | Description                          | Type          | Default | Required |
| -------- | ------------------------------------ | ------------- | ------- | :------: |
| app_name | Application name for resource naming | `string`      | n/a     |   yes    |
| tags     | Tags to apply to resources           | `map(string)` | `{}`    |    no    |

## Outputs

| Name         | Description             |
| ------------ | ----------------------- |
| cluster_name | Name of the ECS cluster |
| cluster_arn  | ARN of the ECS cluster  |

## AWS CLI Commands

### List Clusters

```bash
aws ecs list-clusters --region ap-northeast-1
```

### Describe Cluster

```bash
aws ecs describe-clusters --clusters staging-myapp --region ap-northeast-1
```

### List Services in Cluster

```bash
aws ecs list-services --cluster staging-myapp --region ap-northeast-1
```

### List Tasks in Cluster

```bash
aws ecs list-tasks --cluster staging-myapp --region ap-northeast-1
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
