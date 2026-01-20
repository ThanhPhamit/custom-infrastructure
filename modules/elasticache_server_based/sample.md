# Network Module - Sample Usage

## main.tf

```terraform
module "elasticache_server_based" {
  source = "../modules/elasticache_server_based"

  app_name = "${var.environment}-${var.app_name}"
  vpc_id   = data.aws_vpc.this.id

  subnet_ids = [for subnet in data.aws_subnet.private_subnets : subnet.id]

  engine                = "valkey"
  engine_version        = "8.0"
  node_type             = "cache.t3.micro"
  parameter_group_name  = "default.valkey8"
  number_cache_clusters = var.number_cache_clusters

  tags = local.tags
}
```

## variables.tf

```terraform
variable "number_cache_clusters" {
  type = number
}
```

## terraform.tfvars

```hcl
number_cache_clusters = 1
```

## Outputs

```terraform

```
