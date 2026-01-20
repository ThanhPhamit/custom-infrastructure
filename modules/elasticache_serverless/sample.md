# Network Module - Sample Usage

## main.tf

```terraform
module "elasticache_serverless" {
  source = "../modules/elasticache_serverless"

  app_name = var.app_name
  vpc_id   = data.aws_vpc.this.id

  subnet_ids = [for subnet in data.aws_subnet.elasticache_serverless_subnets : subnet.id]

  tags = local.tags
}
```

## variables.tf

```terraform
variable "elasticache_serverless_subnet_ids" {
  description = "List of subnet IDs for the Elasticache Serverless instance"
  type        = list(string)
}
```

## terraform.tfvars

```hcl
elasticache_serverless_subnet_ids = ["subnet-05299a24f3e6ad5a0", "subnet-0d052d81b1c098346"]
```

## Outputs

```terraform

```
