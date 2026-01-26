# AWS OIDC with GitHub Actions Terraform Module

Terraform module which creates OIDC provider and IAM role for GitHub Actions on AWS.

## Features

This module supports creating:

- **OIDC Provider** - GitHub Actions OIDC identity provider (optional)
- **IAM Role** - Role assumable by GitHub Actions workflows
- **IAM Policies** - Permissions for ECR, ECS, CodeDeploy, and PassRole
- **Repository Trust** - Trust policy for specific GitHub repositories

## Usage

### Example 1: Create OIDC Provider (First time setup)

```terraform
module "aws_oidc_with_github_actions" {
  source = "../../modules/aws_oidc_with_github_actions"

  app_name        = "${var.environment}-${var.app_name}"
  thumbprint_list = var.thumbprint_list
  github_org      = "your-organization"
  github_repositories = [
    "your-app-infrastructure",
    "your-app-server",
    "your-app-client"
  ]

  passrole_target_role_arns = [
    module.ecs_api.ecs_task_role_arn,
    module.ecs_api.ecs_task_execution_role_arn
  ]

  tags = {
    Environment = "production"
    Terraform   = "true"
  }

  depends_on = [module.ecs_api]
}
```

### Example 2: Use Existing OIDC Provider

```terraform
module "aws_oidc_with_github_actions" {
  source = "../../modules/aws_oidc_with_github_actions"

  create_oidc_provider = false  # OIDC provider already exists
  app_name             = "${var.environment}-${var.app_name}"
  thumbprint_list      = var.thumbprint_list
  github_org           = "your-organization"
  github_repositories = [
    "your-second-app-server",
    "your-second-app-client"
  ]

  passrole_target_role_arns = [
    module.ecs_web.ecs_task_role_arn,
    module.ecs_web.ecs_task_execution_role_arn
  ]

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: Multiple Environments with Shared OIDC

```terraform
# First environment - creates OIDC provider
module "oidc_production" {
  source = "../../modules/aws_oidc_with_github_actions"

  create_oidc_provider = true
  app_name             = "production-myapp"
  github_org           = "your-organization"
  github_repositories  = ["myapp-backend"]

  passrole_target_role_arns = [
    module.ecs_production.ecs_task_role_arn,
    module.ecs_production.ecs_task_execution_role_arn
  ]
}

# Second environment - uses existing OIDC provider
module "oidc_staging" {
  source = "../../modules/aws_oidc_with_github_actions"

  create_oidc_provider = false  # Reuse existing provider
  app_name             = "staging-myapp"
  github_org           = "your-organization"
  github_repositories  = ["myapp-backend"]

  passrole_target_role_arns = [
    module.ecs_staging.ecs_task_role_arn,
    module.ecs_staging.ecs_task_execution_role_arn
  ]

  depends_on = [module.oidc_production]
}
```

## GitHub Actions Workflow Configuration

Use the created role in your GitHub Actions workflow:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-oidc-role
          aws-region: ap-northeast-1

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      # ... rest of deployment steps
```

## Generate the Thumbprint

To generate the thumbprint, you can use the following OpenSSL command to get the SHA-1 thumbprint of the OIDC provider's certificate:

```sh
echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}'
```

This command will output the SHA-1 thumbprint of the certificate.

## IAM Permissions Granted

The module grants the following permissions to the GitHub Actions role:

| Service    | Actions                                                   |
| ---------- | --------------------------------------------------------- |
| ECR        | GetAuthorizationToken, BatchCheckLayerAvailability        |
|            | GetDownloadUrlForLayer, BatchGetImage, PutImage           |
|            | InitiateLayerUpload, UploadLayerPart, CompleteLayerUpload |
| ECS        | DescribeTaskDefinition, RegisterTaskDefinition            |
|            | DescribeServices, UpdateService                           |
| CodeDeploy | CreateDeployment, GetDeployment                           |
|            | GetDeploymentConfig, RegisterApplicationRevision          |
| S3         | GetObject, PutObject (for CodeDeploy bucket)              |
| IAM        | PassRole (for specified ECS roles)                        |

## Inputs

| Name                      | Description                          | Type           | Default                    | Required |
| ------------------------- | ------------------------------------ | -------------- | -------------------------- | :------: |
| app_name                  | Application name for resource naming | `string`       | n/a                        |   yes    |
| github_org                | GitHub organization name             | `string`       | n/a                        |   yes    |
| github_repositories       | List of GitHub repository names      | `list(string)` | n/a                        |   yes    |
| passrole_target_role_arns | ARNs of IAM roles that can be passed | `list(string)` | n/a                        |   yes    |
| create_oidc_provider      | Whether to create the OIDC provider  | `bool`         | `true`                     |    no    |
| oidc_url                  | URL of the OIDC identity provider    | `string`       | `https://token.actions...` |    no    |
| client_id_list            | List of client IDs (audiences)       | `list(string)` | `["sts.amazonaws.com"]`    |    no    |
| thumbprint_list           | Server certificate thumbprints       | `list(string)` | Default GitHub thumbprints |    no    |
| iam_role_name             | Name of the IAM role                 | `string`       | `"github-oidc-role"`       |    no    |
| iam_role_description      | Description of the IAM role          | `string`       | `"IAM role to enable..."`  |    no    |
| max_session_duration      | Maximum session duration in seconds  | `number`       | `3600`                     |    no    |
| tags                      | Tags to apply to resources           | `map(string)`  | `{}`                       |    no    |

## Outputs

| Name                     | Description                         |
| ------------------------ | ----------------------------------- |
| oidc_provider_arn        | ARN of the OIDC provider            |
| github_actions_role_arn  | ARN of the GitHub Actions IAM role  |
| github_actions_role_name | Name of the GitHub Actions IAM role |

## Important Notes

1. **OIDC Provider is Account-Wide**: Only create one OIDC provider per AWS account. Set `create_oidc_provider = false` for additional environments.

2. **Thumbprint Updates**: GitHub occasionally updates their certificate thumbprint. Keep `thumbprint_list` updated.

3. **Repository Trust**: The role can only be assumed by workflows running in the specified repositories.

4. **PassRole Permissions**: Ensure all ECS task roles are included in `passrole_target_role_arns`.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
