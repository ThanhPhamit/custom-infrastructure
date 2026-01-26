# AWS VPC Endpoints Network Terraform Module

Terraform module which creates VPC Interface and Gateway endpoints for AWS services.

## Features

This module supports creating:

- **ECR Endpoints** - ECR Docker Registry and API endpoints
- **S3 Gateway Endpoint** - Free S3 access without NAT
- **CloudWatch Logs Endpoint** - Container logging
- **ECS Exec Endpoints** - SSM, SSM Messages, EC2 Messages
- **Security Group** - Endpoint access control
- **VPN Client Access** - Optional VPN client CIDR support

## Usage

### Example 1: Basic VPC Endpoints for ECS

```terraform
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints-network"

  app_name   = "${var.environment}-${var.app_name}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  allowed_security_group_ids = [
    module.ecs_api.ecs_security_group_id,
    module.ecs_web.ecs_security_group_id
  ]

  route_table_ids           = module.network.private_route_table_ids
  enable_ecs_exec_endpoints = false

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: VPC Endpoints with ECS Exec Support

```terraform
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints-network"

  app_name   = "${var.environment}-${var.app_name}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  allowed_security_group_ids = [
    module.ecs_api.ecs_security_group_id,
    module.ecs_web.ecs_security_group_id
  ]

  route_table_ids           = module.network.private_route_table_ids
  enable_ecs_exec_endpoints = true  # Enable SSM endpoints for ECS Exec

  tags = local.tags
}
```

### Example 3: VPC Endpoints with VPN Client Access

```terraform
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints-network"

  app_name   = "${var.environment}-${var.app_name}"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  allowed_security_group_ids = [
    module.ecs_api.ecs_security_group_id
  ]

  route_table_ids           = module.network.private_route_table_ids
  enable_ecs_exec_endpoints = true

  # Allow VPN clients to access VPC endpoints
  vpn_client_cidr_blocks = [
    var.client_cidr_block  # e.g., "172.24.0.0/22"
  ]

  tags = local.tags
}
```

## VPC Endpoints Created

| Endpoint    | Type      | Cost      | Purpose               |
| ----------- | --------- | --------- | --------------------- |
| ecr.dkr     | Interface | ~$7/month | Pull Docker images    |
| ecr.api     | Interface | ~$7/month | ECR API calls         |
| s3          | Gateway   | Free      | S3 access without NAT |
| logs        | Interface | ~$7/month | CloudWatch Logs       |
| ssm         | Interface | ~$7/month | ECS Exec (optional)   |
| ssmmessages | Interface | ~$7/month | ECS Exec (optional)   |
| ec2messages | Interface | ~$7/month | ECS Exec (optional)   |

## Cost Comparison: NAT vs VPC Endpoints

For ECS workloads that pull images and send logs:

| Configuration                 | Monthly Cost (estimate) |
| ----------------------------- | ----------------------- |
| NAT Gateway only              | ~$32 + data transfer    |
| NAT + VPC Endpoints (no exec) | ~$32 + ~$21 = ~$53      |
| VPC Endpoints only (no NAT)   | ~$21-$42                |

VPC Endpoints are cost-effective when:

- Most traffic is to AWS services (ECR, S3, CloudWatch)
- You don't need general internet access from private subnets

## ECS Exec Requirements

To use ECS Exec, you need:

1. VPC endpoints: `ssm`, `ssmmessages`, `ec2messages`
2. Task role with SSM permissions
3. ECS service with `enableExecuteCommand = true`

```bash
# Execute command in ECS task
aws ecs execute-command \
  --cluster my-cluster \
  --task task-id \
  --container container-name \
  --interactive \
  --command "/bin/sh"
```

## Inputs

| Name                       | Description                          | Type           | Default | Required |
| -------------------------- | ------------------------------------ | -------------- | ------- | :------: |
| app_name                   | Application name for resource naming | `string`       | n/a     |   yes    |
| vpc_id                     | VPC ID                               | `string`       | n/a     |   yes    |
| subnet_ids                 | Subnet IDs for interface endpoints   | `list(string)` | n/a     |   yes    |
| allowed_security_group_ids | Security groups allowed to access    | `list(string)` | n/a     |   yes    |
| route_table_ids            | Route table IDs for S3 gateway       | `list(string)` | n/a     |   yes    |
| enable_ecs_exec_endpoints  | Enable SSM endpoints for ECS Exec    | `bool`         | `false` |    no    |
| vpn_client_cidr_blocks     | VPN client CIDRs for endpoint access | `list(string)` | `[]`    |    no    |
| tags                       | Tags to apply to resources           | `map(string)`  | `{}`    |    no    |

## Outputs

| Name                            | Description                     |
| ------------------------------- | ------------------------------- |
| vpc_endpoints_security_group_id | Security group ID for endpoints |
| ecr_dkr_endpoint_id             | ECR Docker endpoint ID          |
| ecr_api_endpoint_id             | ECR API endpoint ID             |
| s3_endpoint_id                  | S3 gateway endpoint ID          |
| cloudwatch_logs_endpoint_id     | CloudWatch Logs endpoint ID     |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
