# Network Module - Sample Usage

## main.tf

```terraform
module "ecs_cluster_nuxt" {
  source = "../modules/ecs_cluster"

  app_name = "${var.environment}-${var.app_name}-nuxt"

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
