# AWS Client VPN Endpoint Terraform Module

Terraform module which creates AWS Client VPN Endpoint with mutual authentication.

## Features

This module supports creating:

- **Client VPN Endpoint** - Managed VPN service for remote access
- **Server & Client Certificates** - Self-signed certificates for mutual authentication
- **ACM Import** - Certificates imported to AWS Certificate Manager
- **Network Associations** - VPN endpoint subnet associations
- **Authorization Rules** - Network access control rules
- **Security Group** - Traffic control for VPN connections

## Usage

### Example 1: Full Tunnel VPN (All Traffic via VPN)

```terraform
module "client_vpn" {
  source = "../../modules/client_VPN_endpoints"

  organization_name = var.organization_name
  app_name          = "${var.environment}-${var.app_name}"
  vpn_domain        = var.vpn_domain

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnets

  client_cidr_block = "172.24.0.0/22"

  allowed_cidr_blocks = var.vpn_allowed_cidr_blocks

  split_tunnel         = false  # All traffic via VPN
  private_subnet_cidrs = module.network.private_subnets_cidr_blocks

  enable_vpn_associations = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Split Tunnel VPN (Only VPC Traffic via VPN)

```terraform
module "client_vpn" {
  source = "../../modules/client_VPN_endpoints"

  organization_name = var.organization_name
  app_name          = "${var.environment}-${var.app_name}"
  vpn_domain        = var.vpn_domain

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnets

  client_cidr_block = "172.24.0.0/22"

  allowed_cidr_blocks = ["0.0.0.0/0"]

  split_tunnel         = true  # Only VPC traffic via VPN
  private_subnet_cidrs = module.network.private_subnets_cidr_blocks

  enable_vpn_associations = true

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: VPN with Disabled Associations (Cost Saving)

```terraform
module "client_vpn" {
  source = "../../modules/client_VPN_endpoints"

  organization_name = var.organization_name
  app_name          = "${var.environment}-${var.app_name}"
  vpn_domain        = var.vpn_domain

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnets

  client_cidr_block = "172.24.0.0/22"

  allowed_cidr_blocks = var.vpn_allowed_cidr_blocks

  split_tunnel         = true
  private_subnet_cidrs = module.network.private_subnets_cidr_blocks

  # Disable associations to save costs when VPN not in use
  enable_vpn_associations = false

  tags = {
    Environment = "development"
    Terraform   = "true"
  }
}
```

## VPN Configuration Options

| Option                            | Description                                  |
| --------------------------------- | -------------------------------------------- |
| `split_tunnel = true`             | Only VPC traffic routed through VPN          |
| `split_tunnel = false`            | All traffic routed through VPN (full tunnel) |
| `enable_vpn_associations = true`  | Enable subnet associations (billable)        |
| `enable_vpn_associations = false` | Disable associations to save costs           |

## Client CIDR Block Selection

The `client_cidr_block` must:

- Not overlap with VPC CIDR
- Be at least /22 (1024 IPs)
- Not overlap with other networks

| VPC CIDR       | Recommended Client CIDR |
| -------------- | ----------------------- |
| 10.0.0.0/16    | 172.24.0.0/22           |
| 192.168.0.0/16 | 10.100.0.0/22           |
| 172.16.0.0/12  | 192.168.100.0/22        |

## Client Configuration

After deployment, download the client configuration:

```bash
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id <endpoint-id> \
  --output text > vpn-config.ovpn
```

### Supported VPN Clients

- AWS VPN Client (recommended)
- OpenVPN Connect
- Tunnelblick (macOS)

## Cost Considerations

| Component               | Cost (Tokyo Region)      |
| ----------------------- | ------------------------ |
| VPN Endpoint            | ~$0.10/hour (~$72/month) |
| Each Subnet Association | ~$0.10/hour (~$72/month) |
| Data Transfer           | Standard AWS data rates  |

**Cost Optimization Tips:**

- Use `enable_vpn_associations = false` when not needed
- Use split tunnel to reduce data transfer costs
- Associate only necessary subnets

## Inputs

| Name                              | Description                            | Type           | Default         | Required |
| --------------------------------- | -------------------------------------- | -------------- | --------------- | :------: |
| organization_name                 | Organization name for certificates     | `string`       | n/a             |   yes    |
| app_name                          | Application name for resource naming   | `string`       | n/a             |   yes    |
| vpn_domain                        | Domain name for VPN server certificate | `string`       | n/a             |   yes    |
| vpc_id                            | VPC ID for the VPN endpoint            | `string`       | n/a             |   yes    |
| subnet_ids                        | Subnet IDs for VPN associations        | `list(string)` | n/a             |   yes    |
| private_subnet_cidrs              | Private subnet CIDRs for routing       | `list(string)` | n/a             |   yes    |
| client_cidr_block                 | CIDR block for VPN clients             | `string`       | `"10.0.0.0/16"` |    no    |
| allowed_cidr_blocks               | CIDR blocks allowed to connect         | `list(string)` | `["0.0.0.0/0"]` |    no    |
| split_tunnel                      | Enable split tunneling                 | `bool`         | `true`          |    no    |
| enable_vpn_associations           | Enable subnet associations             | `bool`         | `true`          |    no    |
| certificate_validity_period_hours | Certificate validity in hours          | `number`       | `8760`          |    no    |
| tags                              | Tags to apply to resources             | `map(string)`  | `{}`            |    no    |

## Outputs

| Name                    | Description                            |
| ----------------------- | -------------------------------------- |
| client_vpn_endpoint_id  | ID of the Client VPN endpoint          |
| client_vpn_endpoint_dns | DNS name of the Client VPN endpoint    |
| vpn_security_group_id   | Security group ID for the VPN endpoint |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |
| tls       | >= 4.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
