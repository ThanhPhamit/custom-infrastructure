# AWS ElastiCache Serverless Terraform Module

Terraform module which creates an ElastiCache Serverless cache for Redis.

## Features

This module supports creating:

- **Serverless Cache** - Auto-scaling Redis cache
- **Security Group** - Access control
- **VPC Configuration** - Private network access

## Usage

### Example 1: Basic Serverless Cache

```terraform
module "elasticache_serverless" {
  source = "../../modules/elasticache_serverless"

  app_name   = "${var.environment}-${var.app_name}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Using with ECS Service

```terraform
module "elasticache_serverless" {
  source = "../../modules/elasticache_serverless"

  app_name   = "${var.environment}-${var.app_name}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  allowed_security_groups = [
    module.ecs_api.ecs_security_group_id,
    module.ecs_worker.ecs_security_group_id
  ]

  tags = local.tags
}

module "ecs_api" {
  source = "../../modules/ecs_nest"

  # ... other configuration ...

  redis_url = "rediss://${module.elasticache_serverless.primary_endpoint[0].address}:${module.elasticache_serverless.primary_endpoint[0].port}"
}
```

## Server-Based vs Serverless Comparison

| Feature       | Server-Based              | Serverless             |
| ------------- | ------------------------- | ---------------------- |
| Scaling       | Manual (node type change) | Automatic              |
| Pricing       | Per node (hourly)         | Per request + storage  |
| Minimum cost  | ~$12/month (t3.micro)     | ~$90/month (base)      |
| Best for      | Predictable workloads     | Variable/unpredictable |
| Configuration | Full control              | Limited options        |
| Failover      | Manual setup              | Built-in               |

## When to Use Serverless

✅ **Use Serverless when:**

- Traffic is unpredictable or spiky
- You want zero management overhead
- You need automatic scaling
- Cost is acceptable for convenience

❌ **Use Server-Based when:**

- Traffic is predictable
- Cost optimization is critical
- You need specific Redis configurations
- You need fine-grained control

## Pricing Considerations

ElastiCache Serverless pricing:

- **Data stored**: ~$0.125/GB-hour
- **ECPUs consumed**: ~$0.0000034/ECPU
- **Minimum**: ~$90/month baseline

For low-traffic applications, server-based (cache.t3.micro) may be more cost-effective.

## Connection Examples

### Node.js (with TLS)

```javascript
const Redis = require('ioredis');
const client = new Redis({
  host: 'endpoint.serverless.cache.amazonaws.com',
  port: 6379,
  tls: {}, // Serverless requires TLS
});
```

### Python (with TLS)

```python
import redis
r = redis.Redis(
    host='endpoint.serverless.cache.amazonaws.com',
    port=6379,
    ssl=True,  # Serverless requires TLS
    decode_responses=True
)
```

## Inputs

| Name                    | Description                           | Type           | Default | Required |
| ----------------------- | ------------------------------------- | -------------- | ------- | :------: |
| app_name                | Application name for resource naming  | `string`       | n/a     |   yes    |
| vpc_id                  | VPC ID                                | `string`       | n/a     |   yes    |
| subnet_ids              | Subnet IDs for the cache              | `list(string)` | n/a     |   yes    |
| allowed_security_groups | Additional security groups for access | `list(string)` | `[]`    |    no    |
| tags                    | Tags to apply to resources            | `map(string)`  | `{}`    |    no    |

## Outputs

| Name              | Description              |
| ----------------- | ------------------------ |
| security_group_id | Security group ID        |
| primary_endpoint  | Primary endpoint details |
| reader_endpoint   | Reader endpoint details  |

## Endpoint Format

Serverless endpoints use a different format:

```
# Primary endpoint
endpoint.serverless.apne1.cache.amazonaws.com:6379

# Reader endpoint (same as primary for serverless)
endpoint.serverless.apne1.cache.amazonaws.com:6379
```

**Note:** ElastiCache Serverless always requires TLS connections.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
