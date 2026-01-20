# AWS OIDC with GitHub Actions - Sample Usage

## Example 1: Create OIDC Provider (First time setup)

```terraform
module "aws_oidc_with_github_actions" {
  source = "../../modules/aws_oidc_with_github_actions"

  app_name        = var.app_name
  thumbprint_list = var.thumbprint_list
  github_org      = "liongarden"
  github_repositories = [
    "welfan-namecard-infrastructure",
    "welfan-namecard-server",
    "welfan-namecard-client"
  ]

  passrole_target_role_arns = [
    module.ecs_api.ecs_task_role_arn,
    module.ecs_api.ecs_task_execution_role_arn
  ]

  tags = local.tags

  depends_on = [module.ecs_api]
}
```

---

## Example 2: Use Existing OIDC Provider

```terraform
module "aws_oidc_with_github_actions" {
  source = "../../modules/aws_oidc_with_github_actions"

  create_oidc_provider = false
  app_name             = "${var.environment}-${var.app_name}"
  thumbprint_list      = var.thumbprint_list
  github_org           = "liongarden"
  github_repositories = [
    "welfan-warehouse-infrastructure",
    "welfan-warehouse-server",
    "welfan-warehouse-client"
  ]

  passrole_target_role_arns = [
    module.ecs_nuxt.ecs_task_role_arn,
    module.ecs_nuxt.ecs_task_execution_role_arn,
    module.ecs_nest.ecs_task_role_arn,
    module.ecs_nest.ecs_task_execution_role_arn
  ]

  tags = local.tags
}
```

---

## variables.tf

```terraform
variable "thumbprint_list" {
  description = "A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)."
  type        = list(string)
}
```

---

## terraform.tfvars

```hcl
thumbprint_list = ["74f3a68f16524f15424927704c9506f55a9316bd"]
```

---

## Outputs

```terraform
module.aws_oidc_with_github_actions.oidc_provider_arn
module.aws_oidc_with_github_actions.github_actions_role_arn
module.aws_oidc_with_github_actions.github_actions_role_name
```
