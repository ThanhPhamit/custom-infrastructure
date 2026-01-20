# Network Module - Sample Usage

## main.tf

```terraform
module "ecr_private_registry_nuxt" {
  source = "../modules/ecr_private_registry"

  repository_name = "${var.environment}-${var.app_name}-nuxt"
  tags            = local.tags
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
