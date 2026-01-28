# AWS ElastiCache (Server-Based) Terraform Module

Terraform module which creates an ElastiCache Redis/Valkey replication group.

## Features

This module supports creating:

- **Replication Group** - Primary with optional read replicas
- **Subnet Group** - Network configuration
- **Security Group** - Access control
- **Parameter Group** - Custom Redis/Valkey parameters
- **Automatic Failover** - Multi-AZ support
- **Encryption** - In-transit and at-rest encryption

## Usage

### Example 1: Single Node (Development/Staging)

```terraform
module "elasticache" {
  source = "../../modules/elasticache_server_based"

  app_name = "${var.environment}-${var.app_name}"
  vpc_id   = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  engine                = "valkey"
  engine_version        = "8.0"
  node_type             = "cache.t3.micro"
  parameter_group_name  = "default.valkey8"
  number_cache_clusters = 1

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 2: Multi-Node with Failover (Production)

```terraform
module "elasticache" {
  source = "../../modules/elasticache_server_based"

  app_name = "${var.environment}-${var.app_name}"
  vpc_id   = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  engine                = "redis"
  engine_version        = "7.0"
  node_type             = "cache.r6g.large"
  parameter_group_name  = "default.redis7"
  number_cache_clusters = 3  # 1 primary + 2 replicas

  # High availability
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Security
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true

  # Backup
  snapshot_retention_limit = 7
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: Using Existing Subnet Group

```terraform
module "elasticache" {
  source = "../../modules/elasticache_server_based"

  app_name = "${var.environment}-${var.app_name}"
  vpc_id   = module.network.vpc_id

  # Use subnet group from network module
  elasticache_subnet_group_name = module.network.elasticache_subnet_group_name

  engine                = "valkey"
  engine_version        = "8.0"
  node_type             = "cache.t3.micro"
  parameter_group_name  = "default.valkey8"
  number_cache_clusters = 1

  tags = local.tags
}
```

### Example 4: With CloudWatch Alarm Support

The `enable_cache_nodes_lookup` variable controls whether to query cache node details for CloudWatch alarms.

**Initial deployment** (cluster doesn't exist yet):

```terraform
module "elasticache" {
  source = "../../modules/elasticache_server_based"

  app_name = "${var.environment}-${var.app_name}"
  vpc_id   = module.vpc.vpc_id

  elasticache_subnet_group_name = module.vpc.elasticache_subnet_group_name

  engine                = "valkey"
  engine_version        = "8.0"
  node_type             = "cache.t3.micro"
  parameter_group_name  = "default.valkey8"
  number_cache_clusters = 1

  # First deployment: disable lookup (cluster doesn't exist yet)
  enable_cache_nodes_lookup = false

  tags = local.tags
}
```

**After cluster is created** (enable for CloudWatch alarms):

```terraform
module "elasticache" {
  # ... same config ...

  # Enable after cluster exists to get cache_nodes output
  enable_cache_nodes_lookup = true
}

# Now you can use cache_nodes output for CloudWatch alarms
module "cloudwatch_alarm_elasticache" {
  source = "../../modules/cloudwatch_alarm_elasticache_server_based"

  cache_nodes = module.elasticache.cache_nodes
  # ...
}
```

## Engine Options

| Engine | Version | Description                |
| ------ | ------- | -------------------------- |
| redis  | 7.0     | Redis OSS                  |
| valkey | 8.0     | Valkey (Redis fork by AWS) |

## Node Type Recommendations

| Environment | Node Type        | vCPU | Memory | Cost     |
| ----------- | ---------------- | ---- | ------ | -------- |
| Development | cache.t3.micro   | 2    | 0.5GB  | ~$12/mo  |
| Staging     | cache.t3.small   | 2    | 1.4GB  | ~$24/mo  |
| Production  | cache.r6g.large  | 2    | 13GB   | ~$150/mo |
| Heavy       | cache.r6g.xlarge | 4    | 26GB   | ~$300/mo |

## High Availability Configuration

| Configuration | Clusters | Failover | Multi-AZ | Use Case    |
| ------------- | -------- | -------- | -------- | ----------- |
| Single        | 1        | No       | No       | Development |
| Basic HA      | 2        | Yes      | No       | Staging     |
| Production HA | 3        | Yes      | Yes      | Production  |

## Connection Examples

### Node.js

```javascript
const Redis = require('ioredis');
const client = new Redis({
  host: 'primary-endpoint.cache.amazonaws.com',
  port: 6379,
});
```

### Python

```python
import redis
r = redis.Redis(
    host='primary-endpoint.cache.amazonaws.com',
    port=6379,
    decode_responses=True
)
```

## Inputs

| Name                          | Description                          | Type           | Default                 | Required |
| ----------------------------- | ------------------------------------ | -------------- | ----------------------- | :------: |
| app_name                      | Application name for resource naming | `string`       | n/a                     |   yes    |
| vpc_id                        | VPC ID                               | `string`       | n/a                     |   yes    |
| subnet_ids                    | Subnet IDs for subnet group          | `list(string)` | `[]`                    |   no\*   |
| elasticache_subnet_group_name | Existing subnet group name           | `string`       | `null`                  |   no\*   |
| number_cache_clusters         | Number of cache nodes                | `number`       | n/a                     |   yes    |
| engine                        | Cache engine (redis/valkey)          | `string`       | `"redis"`               |    no    |
| engine_version                | Engine version                       | `string`       | `"7.0"`                 |    no    |
| node_type                     | Instance type                        | `string`       | `"cache.t4g.micro"`     |    no    |
| port                          | Port number                          | `number`       | `6379`                  |    no    |
| parameter_group_name          | Parameter group name                 | `string`       | `"default.redis7"`      |    no    |
| automatic_failover_enabled    | Enable automatic failover            | `bool`         | `false`                 |    no    |
| multi_az_enabled              | Enable Multi-AZ                      | `bool`         | `false`                 |    no    |
| snapshot_retention_limit      | Snapshot retention days              | `number`       | `2`                     |    no    |
| snapshot_window               | Snapshot window (UTC)                | `string`       | `"17:00-18:00"`         |    no    |
| maintenance_window            | Maintenance window (UTC)             | `string`       | `"Sat:18:00-Sat:19:00"` |    no    |
| transit_encryption_enabled    | Enable in-transit encryption         | `bool`         | `false`                 |    no    |
| at_rest_encryption_enabled    | Enable at-rest encryption            | `bool`         | `false`                 |    no    |
| enable_cache_nodes_lookup     | Enable cache nodes lookup for alarms | `bool`         | `false`                 |    no    |
| apply_immediately             | Apply changes immediately            | `bool`         | `true`                  |    no    |
| allowed_security_groups       | Additional security groups           | `list(string)` | `[]`                    |    no    |
| tags                          | Tags to apply to resources           | `map(string)`  | `{}`                    |    no    |

\*Either `subnet_ids` or `elasticache_subnet_group_name` must be provided

## Outputs

| Name                     | Description                                                                   |
| ------------------------ | ----------------------------------------------------------------------------- |
| security_group_id        | Security group ID                                                             |
| primary_endpoint_address | Primary endpoint address                                                      |
| reader_endpoint_address  | Reader endpoint address                                                       |
| primary_endpoint_port    | Primary endpoint port                                                         |
| replication_group_id     | Replication group ID                                                          |
| cluster_id               | Cluster ID                                                                    |
| cache_nodes              | Map of cache nodes with details (requires `enable_cache_nodes_lookup = true`) |

## Deployment Workflow

### Two-Step Deployment for CloudWatch Alarms

Since `cache_nodes` output requires the cluster to exist first, follow this workflow:

1. **First deployment** - Create the cluster:

   ```hcl
   enable_cache_nodes_lookup = false  # default
   ```

   ```bash
   terraform apply
   ```

2. **Second deployment** - Enable cache nodes lookup:

   ```hcl
   enable_cache_nodes_lookup = true
   ```

   ```bash
   terraform apply
   ```

3. **Now** you can add CloudWatch alarms using `module.elasticache.cache_nodes`

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
