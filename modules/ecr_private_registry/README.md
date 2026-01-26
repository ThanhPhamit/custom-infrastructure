# AWS ECR Private Registry Terraform Module

Terraform module which creates an ECR private repository for Docker images.

## Features

This module supports creating:

- **ECR Repository** - Private Docker image repository
- **Lifecycle Policy** - Automatic cleanup of old images
- **Repository Policy** - Access control configuration
- **Image Scanning** - Vulnerability scanning on push

## Usage

### Example 1: Basic ECR Repository

```terraform
module "ecr_api" {
  source = "../../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-api"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Multiple Repositories

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

The module includes a default lifecycle policy that:

- Keeps the last 30 tagged images
- Removes untagged images older than 1 day
- Helps manage storage costs

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

| Name            | Description                | Type          | Default | Required |
| --------------- | -------------------------- | ------------- | ------- | :------: |
| repository_name | Name of the ECR repository | `string`      | n/a     |   yes    |
| tags            | Tags to apply to resources | `map(string)` | `{}`    |    no    |

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
