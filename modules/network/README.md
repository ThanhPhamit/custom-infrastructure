# AWS VPC Terraform Module

Terraform module which creates VPC resources on AWS.

## Features

This module supports creating:

- **VPC** with customizable CIDR block and DNS settings
- **Public Subnets** - with Internet Gateway route
- **Private Subnets** - with NAT Gateway route (optional)
- **Database Subnets** - with optional DB subnet group
- **ElastiCache Subnets** - with optional ElastiCache subnet group
- **Intra Subnets** - isolated subnets without internet access
- **NAT Gateway** - single, one per AZ, or reuse existing EIPs
- **Internet Gateway** - for public subnet internet access
- **VPC Endpoints** - S3 and DynamoDB Gateway endpoints
- **Route Tables** - separate route tables for each subnet type
- **Default Security Group** - managed default security group
- **Default Network ACL** - managed default network ACL
- **DHCP Options Set** - optional custom DHCP options

## Usage

### Basic Example

```terraform
module "vpc" {
  source = "../../modules/network"

  name       = "my-vpc"
  aws_region = "ap-northeast-1"
  vpc_cidr   = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

### Complete Example (Staging - Cost Optimized)

```terraform
module "vpc" {
  source = "../../modules/network"

  name       = "staging-vpc"
  aws_region = "ap-northeast-1"
  vpc_cidr   = "10.0.0.0/16"

  azs                 = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets    = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  elasticache_subnets = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]

  # NAT Gateway - Single NAT for cost saving (~$32/month vs ~$96/month)
  enable_nat_gateway = true
  single_nat_gateway = true

  # Database - isolated, connect via bastion/app only
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  create_database_nat_gateway_route  = false

  # ElastiCache - isolated, connect via bastion/app only
  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  create_elasticache_nat_gateway_route  = false

  # VPC Endpoints (free - Gateway type)
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Security: Lock down default security group
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Complete Example (Production)

```terraform
module "vpc" {
  source = "../../modules/network"

  name       = "production-vpc"
  aws_region = "ap-northeast-1"
  vpc_cidr   = "10.0.0.0/16"

  azs                 = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets    = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  elasticache_subnets = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]
  intra_subnets       = ["10.0.41.0/24", "10.0.42.0/24", "10.0.43.0/24"]

  # NAT Gateway - One per AZ for high availability
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Database - isolated, only bastion/app can connect, no NAT needed
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  create_database_nat_gateway_route  = false  # Database does not need internet access

  # ElastiCache - isolated like database, connect via bastion host
  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  create_elasticache_nat_gateway_route  = false  # ElastiCache does not need internet access

  # VPC Endpoints (free - Gateway type)
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Security: Lock down default resources
  manage_default_security_group  = true
  default_security_group_ingress = []  # Block all ingress
  default_security_group_egress  = []  # Block all egress

  manage_default_network_acl = true
  manage_default_route_table = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }

  # Kubernetes tags for ALB Ingress Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
```

## NAT Gateway Scenarios

> **Important:** `single_nat_gateway` takes precedence over `one_nat_gateway_per_az`. When `single_nat_gateway = true`, the `one_nat_gateway_per_az` setting is ignored.

| `single_nat_gateway` | `one_nat_gateway_per_az` | Result                   | Cost (3 AZs) |
| -------------------- | ------------------------ | ------------------------ | ------------ |
| `true`               | (ignored)                | 1 NAT Gateway            | ~$32/month   |
| `false`              | `true`                   | 1 NAT per AZ (3 NATs)    | ~$96/month   |
| `false`              | `false`                  | 1 NAT per private subnet | Varies       |

### Single NAT Gateway (Cost Optimized - Dev/Staging)

```terraform
enable_nat_gateway = true
single_nat_gateway = true
# one_nat_gateway_per_az is not needed when single_nat_gateway = true
```

All private subnets route through a single NAT Gateway. Lower cost but single point of failure.

### One NAT Gateway per AZ (High Availability - Production)

```terraform
enable_nat_gateway     = true
single_nat_gateway     = false  # Must be false to use one_nat_gateway_per_az
one_nat_gateway_per_az = true
```

Each AZ has its own NAT Gateway. Higher cost but better availability.

### External NAT Gateway IPs (Keep IPs after VPC recreation)

```terraform
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"

  tags = {
    Name = "nat-eip-${count.index}"
  }
}

module "vpc" {
  source = "../../modules/network"

  # ...

  enable_nat_gateway  = true
  single_nat_gateway  = false
  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat[*].id
  external_nat_ips    = aws_eip.nat[*].public_ip
}
```

## Subnet Types

| Subnet Type | Internet Access    | Use Case                                    |
| ----------- | ------------------ | ------------------------------------------- |
| Public      | Direct (IGW)       | Load Balancers, Bastion Hosts, NAT Gateways |
| Private     | Via NAT Gateway    | Application servers, ECS tasks, Lambda      |
| Database    | Via NAT (optional) | RDS, Aurora databases                       |
| ElastiCache | Via NAT (optional) | Redis, Memcached clusters                   |
| Intra       | None               | Internal services, Lambda VPC endpoints     |

## Inputs

| Name                     | Description                                    | Type           | Default         | Required |
| ------------------------ | ---------------------------------------------- | -------------- | --------------- | :------: |
| name                     | Name to be used on all resources as identifier | `string`       | `""`            |   yes    |
| vpc_cidr                 | The IPv4 CIDR block for the VPC                | `string`       | `"10.0.0.0/16"` |   yes    |
| aws_region               | AWS region                                     | `string`       | n/a             |   yes    |
| azs                      | List of availability zones                     | `list(string)` | `[]`            |   yes    |
| public_subnets           | List of public subnet CIDRs                    | `list(string)` | `[]`            |    no    |
| private_subnets          | List of private subnet CIDRs                   | `list(string)` | `[]`            |    no    |
| database_subnets         | List of database subnet CIDRs                  | `list(string)` | `[]`            |    no    |
| elasticache_subnets      | List of elasticache subnet CIDRs               | `list(string)` | `[]`            |    no    |
| intra_subnets            | List of intra subnet CIDRs                     | `list(string)` | `[]`            |    no    |
| enable_nat_gateway       | Enable NAT Gateway for private subnets         | `bool`         | `false`         |    no    |
| single_nat_gateway       | Use single NAT Gateway for all AZs             | `bool`         | `false`         |    no    |
| one_nat_gateway_per_az   | Create one NAT Gateway per AZ                  | `bool`         | `false`         |    no    |
| enable_dns_hostnames     | Enable DNS hostnames in VPC                    | `bool`         | `true`          |    no    |
| enable_dns_support       | Enable DNS support in VPC                      | `bool`         | `true`          |    no    |
| enable_s3_endpoint       | Enable S3 VPC Endpoint                         | `bool`         | `false`         |    no    |
| enable_dynamodb_endpoint | Enable DynamoDB VPC Endpoint                   | `bool`         | `false`         |    no    |
| tags                     | Tags to apply to all resources                 | `map(string)`  | `{}`            |    no    |

## Outputs

| Name                          | Description                                            |
| ----------------------------- | ------------------------------------------------------ |
| vpc_id                        | The ID of the VPC                                      |
| vpc_arn                       | The ARN of the VPC                                     |
| vpc_cidr_block                | The CIDR block of the VPC                              |
| public_subnets                | List of IDs of public subnets                          |
| public_subnets_cidr_blocks    | List of CIDR blocks of public subnets                  |
| private_subnets               | List of IDs of private subnets                         |
| private_subnets_cidr_blocks   | List of CIDR blocks of private subnets                 |
| database_subnets              | List of IDs of database subnets                        |
| database_subnet_group         | ID of database subnet group                            |
| database_subnet_group_name    | Name of database subnet group                          |
| elasticache_subnets           | List of IDs of elasticache subnets                     |
| elasticache_subnet_group      | ID of elasticache subnet group                         |
| elasticache_subnet_group_name | Name of elasticache subnet group                       |
| intra_subnets                 | List of IDs of intra subnets                           |
| nat_ids                       | List of allocation IDs of Elastic IPs for NAT Gateways |
| nat_public_ips                | List of public Elastic IPs for NAT Gateways            |
| natgw_ids                     | List of NAT Gateway IDs                                |
| igw_id                        | The ID of the Internet Gateway                         |
| public_route_table_ids        | List of IDs of public route tables                     |
| private_route_table_ids       | List of IDs of private route tables                    |

## Backward Compatibility

This module maintains backward compatibility with the legacy variable names:

```terraform
module "vpc" {
  source = "../../modules/network"

  # Legacy variables (deprecated)
  app_name              = var.app_name
  aws_region            = var.region
  azs_name              = ["a", "c"]  # AZ suffixes
  vpc_cidr              = var.vpc_cidr
  public_subnet_ciders  = var.public_subnet_ciders
  private_subnet_ciders = var.private_subnet_ciders

  # New features
  enable_nat_gateway = true
  single_nat_gateway = true
}
```

## Default VPC Resources

When creating a VPC, AWS automatically creates 3 default resources. This module allows you to **manage** these resources to enhance security.

### Should You Use Them?

| Resource                        | Recommendation     | Reason                                                          |
| ------------------------------- | ------------------ | --------------------------------------------------------------- |
| `manage_default_security_group` | ✅ **Recommended** | Lock down default SG so no one accidentally uses it             |
| `manage_default_network_acl`    | ⚠️ **Optional**    | Default settings are usually sufficient                         |
| `manage_default_route_table`    | ⚠️ **Optional**    | Manage so subnets without explicit association will be isolated |

### Best Practice: Lock Down Default Security Group

```terraform
module "vpc" {
  source = "../../modules/network"

  # ... other config ...

  # Manage default security group - RECOMMENDED
  manage_default_security_group = true
  default_security_group_ingress = []  # Block all ingress
  default_security_group_egress  = []  # Block all egress
  # → Result: Default SG is locked, no traffic allowed
}
```

### Allow Specific Traffic in Default Security Group

```terraform
module "vpc" {
  source = "../../modules/network"

  # ... other config ...

  manage_default_security_group = true

  # Allow instances in the same SG to communicate with each other
  default_security_group_ingress = [
    {
      self        = true
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all from self"
    }
  ]

  default_security_group_egress = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound"
    }
  ]
}
```

### Manage Default Network ACL

```terraform
module "vpc" {
  source = "../../modules/network"

  # ... other config ...

  manage_default_network_acl = true

  # Keep default rules (allow all)
  default_network_acl_ingress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]

  default_network_acl_egress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]
}
```

### Manage Default Route Table

```terraform
module "vpc" {
  source = "../../modules/network"

  # ... other config ...

  manage_default_route_table = true
  default_route_table_routes = []  # No routes added → isolated
  # Subnets without explicit association will use this route table (only local route)
}
```

### Location on AWS Console

| Resource               | Console Path          | How to Identify        |
| ---------------------- | --------------------- | ---------------------- |
| Default Security Group | VPC → Security Groups | Group name = `default` |
| Default Network ACL    | VPC → Network ACLs    | Default column = `Yes` |
| Default Route Table    | VPC → Route tables    | Main column = `Yes`    |

### Production Recommended Config

```terraform
module "vpc" {
  source = "../../modules/network"

  name       = "production-vpc"
  aws_region = "ap-northeast-1"
  vpc_cidr   = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  # NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Database - isolated, no NAT needed
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  create_database_nat_gateway_route  = false

  # ElastiCache - isolated, connect via bastion host
  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  create_elasticache_nat_gateway_route  = false

  # VPC Endpoints (free)
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  # Security: Lock down default resources
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  manage_default_network_acl = true
  manage_default_route_table = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
