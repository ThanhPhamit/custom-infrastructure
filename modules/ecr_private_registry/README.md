# AWS ECR Private Registry Terraform Module

Terraform module which creates an ECR private repository for Docker images.

## Features

This module supports creating:

- **ECR Repository** - Private Docker image repository
- **Lifecycle Policy** - Automatic cleanup with environment-specific retention
- **Image Scanning** - Vulnerability scanning on push (enabled by default)
- **Cost Optimization** - Configurable retention to reduce storage costs

## Usage

### Example 1: Basic ECR Repository (Default)

```terraform
module "ecr_api" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-api"

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 2: Environment-Specific Retention

Configure retention based on environment:

```terraform
# DEV: Keep 20 images (~1-2 weeks)
module "ecr_dev" {
  source = "../../modules/ecr_private_registry"

  repository_name       = "dev-${var.app_name}-api"
  image_retention_count = 20
  untagged_retention_days = 7

  tags = local.tags
}

# STAGING: Keep 50 images (~1 month)
module "ecr_stg" {
  source = "../../modules/ecr_private_registry"

  repository_name       = "stg-${var.app_name}-api"
  image_retention_count = 50  # Keep last 50 for STAGING
  untagged_retention_days = 7

  tags = local.tags
}

# PROD: Keep 100 images (~3 months)
module "ecr_prod" {
  source = "../../modules/ecr_private_registry"

  repository_name       = "prod-${var.app_name}-api"
  image_retention_count = 100  # Keep last 100 for PROD
  untagged_retention_days = 7

  tags = local.tags
}
```

### Example 3: Multiple Repositories

```terraform
module "ecr_nuxt" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-nuxt"
  tags            = local.tags
}

module "ecr_nest" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-nest"
  tags            = local.tags
}

module "ecr_worker" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-worker"
  tags            = local.tags
}
```

### Example 3: Using with ECS

```terraform
module "ecr" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-api"
  tags            = local.tags
}

module "ecs" {
  source = "../../modules/ecs_nest"

  # ... other configuration ...

  repository_url = module.ecr.repository_url
  repository_arn = module.ecr.repository_arn
}
```

## Docker Commands

### Login to ECR

```bash
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com
```

### Build and Push Image

```bash
# Build image
docker build -t my-app:latest .

# Tag image
docker tag my-app:latest <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/staging-my-app-api:latest

# Push image
docker push <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/staging-my-app-api:latest
```

### Pull Image

```bash
docker pull <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/staging-my-app-api:latest
```

## Lifecycle Policy

The module includes an automatic lifecycle policy with two rules:

**Rule 1: Image Count Limit**

- Keeps the last N tagged images (configurable per environment)
- Automatically expires older images when limit is reached
- Helps manage storage costs

**Rule 2: Untagged Image Cleanup**

- Removes untagged images after X days (default: 7 days)
- Prevents orphaned images from consuming storage

### Retention Strategy by Environment

| Environment | Retention Count | Typical Coverage | Use Case                        |
| ----------- | --------------- | ---------------- | ------------------------------- |
| **DEV**     | 20 images       | ~1-2 weeks       | Rapid iteration, short history  |
| **STAGING** | 50 images       | ~1 month         | Testing cycles, medium rollback |
| **PROD**    | 100 images      | ~3 months        | Critical, long-term rollback    |

### Cost Impact

- ECR storage pricing: $0.10/GB/month
- Average image size: ~500MB
- **DEV (20 images)**: ~$1/month
- **STAGING (50 images)**: ~$2.50/month
- **PROD (100 images)**: ~$5/month

Without lifecycle policy (~500 images): ~$25/month → **With policy: ~$8.50/month (66% savings)**

## GitHub Actions Integration

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ap-northeast-1

- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2

- name: Build, tag, and push image to Amazon ECR
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    ECR_REPOSITORY: staging-my-app-api
    IMAGE_TAG: ${{ github.sha }}
  run: |
    docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
```

## Inputs

| Name                    | Description                                                     | Type          | Default | Required |
| ----------------------- | --------------------------------------------------------------- | ------------- | ------- | :------: |
| repository_name         | Name of the ECR repository                                      | `string`      | n/a     |   yes    |
| image_retention_count   | Number of tagged images to retain (DEV: 20, STG: 50, PROD: 100) | `number`      | `50`    |    no    |
| untagged_retention_days | Days to keep untagged images before deletion                    | `number`      | `7`     |    no    |
| tags                    | Tags to apply to resources                                      | `map(string)` | `{}`    |    no    |

## Outputs

| Name           | Description               |
| -------------- | ------------------------- |
| repository_url | URL of the ECR repository |
| repository_arn | ARN of the ECR repository |

## Repository URL Format

```
<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>
```

Example:

```
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/staging-myapp-api
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
