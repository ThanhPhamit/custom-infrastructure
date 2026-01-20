# VPC Endpoints Network Module - Sample Usage

## main.tf

```terraform
module "vpc_endpoints_network" {
  source = "../../modules/vpc-endpoints-network"

  app_name   = var.app_name
  vpc_id     = data.aws_vpc.this.id
  subnet_ids = [for subnet in data.aws_subnet.private_subnets : subnet.id]

  allowed_security_group_ids = concat([
    module.ecs_nuxt.ecs_security_group_id,
    module.ecs_nest.ecs_security_group_id
  ], var.allowed_security_group_ids_for_vpc_endpoints)

  # Allow VPN clients to access VPC endpoints (for Bedrock, etc.)
  vpn_client_cidr_blocks = [
    # var.client_cidr_block,      # UDP VPN
  ]

  route_table_ids           = var.route_table_ids
  enable_ecs_exec_endpoints = var.enable_ecs_exec_endpoints

  tags = local.tags
}
```

## variables.tf

```terraform
variable "app_name" {
  type        = string
  description = "Application name"
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for VPC endpoints"
  type        = list(string)
}

variable "allowed_security_group_ids_for_vpc_endpoints" {
  description = "List of security group IDs that are allowed to access VPC endpoints"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs for S3 gateway endpoint"
  type        = list(string)
}

variable "enable_ecs_exec_endpoints" {
  description = "Enable VPC endpoints required for ECS Exec (SSM, SSM Messages, EC2 Messages)"
  type        = bool
  default     = false
}

variable "vpn_client_cidr_blocks" {
  description = "List of VPN client CIDR blocks that are allowed to access VPC endpoints"
  type        = list(string)
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
```

## terraform.tfvars

```hcl
app_name = "welfan-namecard-staging"

route_table_ids = ["rtb-066f2ea61d3f94525"]

allowed_security_group_ids_for_vpc_endpoints = [
  # From Welfan namecard tool project
  "sg-0c735050a326b18e0",
  "sg-0f8419b5c2927c13a",
  # From mockup ecs nuxt
  "sg-0a01f86305c86ed0a",
  # From amazon-sp-api
  "sg-0175d9ce9d2699bf1",
  # From Production WMS
  "sg-0d1e2edfc804dddfc",
  "sg-05d13bac0944f4011",
  # From Development WMS
  "sg-0b93d083589851a0a",
  "sg-0647cf6abc3d468ba",
  # From Remark AI tool
  "sg-06fe4b60dd93d66e2",   # staging
  "sg-0d35e369c0d0c08e9"    # production
]

enable_ecs_exec_endpoints = true

vpn_client_cidr_blocks = []

tags = {
  Environment = "staging"
  Project     = "welfan-namecard"
  ManagedBy   = "Terraform"
}
```

## Module Features

### VPC Endpoints Created:

- **ECR Docker Registry** (ecr.dkr) - Interface endpoint for pulling Docker images
- **ECR API** (ecr.api) - Interface endpoint for ECR API calls
- **S3** - Gateway endpoint for S3 access
- **CloudWatch Logs** - Interface endpoint for logging
- **SSM** (optional) - For ECS Exec functionality
- **SSM Messages** (optional) - For ECS Exec functionality
- **EC2 Messages** (optional) - For ECS Exec functionality

### Security Configuration:

- Security group allows HTTPS (443) traffic from specified ECS security groups
- Optional VPN client CIDR block support for remote access
- Private DNS enabled for interface endpoints

## Outputs

```terraform
# Access outputs:
module.vpc_endpoints_network.vpc_endpoints_security_group_id
module.vpc_endpoints_network.ecr_dkr_endpoint_id
module.vpc_endpoints_network.ecr_api_endpoint_id
module.vpc_endpoints_network.s3_endpoint_id
module.vpc_endpoints_network.cloudwatch_logs_endpoint_id
```

## Usage Notes

1. **Subnet Selection**: Ensure subnets are private subnets where your ECS tasks run
2. **Security Groups**: Add all security group IDs from ECS clusters that need to access these endpoints
3. **Route Tables**: For S3 gateway endpoint, list all route tables that should route traffic through the endpoint
4. **VPN Access**: If you have VPN clients accessing Bedrock or other services, add their CIDR blocks to `vpn_client_cidr_blocks`
5. **ECS Exec**: Set `enable_ecs_exec_endpoints = true` to create SSM-related endpoints for executing commands in ECS tasks
