# vpc_interface_endpoints

Generic, reusable Terraform module that provisions a set of AWS **interface** VPC
endpoints (AWS PrivateLink) sharing a single security group. The security group
allows inbound HTTPS (TCP 443) from a caller-supplied list of CIDR blocks and has
no egress rules (interface endpoints terminate connections at the ENI).

The module is deliberately service-agnostic: you pass the **short** service names
you want (e.g. `["sts", "secretsmanager"]`) and it expands each to
`com.amazonaws.<region>.<name>`, creating one endpoint per service with one ENI
per subnet.

## Why this exists / what it replaces

This module **replaces the library's ECS-oriented `vpc-endpoints-network` module**
for non-ECS use cases. That module hardcodes ECR/CloudWatch Logs/Bedrock endpoints
and does not include STS. This module exposes only the services a given private VPC
needs.

In this lab it backs a fully private VPC (no IGW/NAT) whose only ingress is an IPsec
Site-to-Site VPN: on-prem reaches **STS** and **Secrets Manager** purely through
these PrivateLink endpoints. Keep `private_dns_enabled = true` so the services'
default regional DNS names resolve to the endpoint ENIs; on-prem resolves those
names via the Route 53 Resolver inbound endpoint.

## Usage

```hcl
module "vpc_interface_endpoints" {
  source = "../../modules/vpc_interface_endpoints"

  app_name = "s2s-vpn-lab"
  vpc_id   = module.network.vpc_id

  # Private subnets that should host endpoint ENIs (one ENI per subnet per service).
  subnet_ids = module.network.private_subnet_ids

  # Short service names; expanded to com.amazonaws.<region>.<name>.
  service_names = ["sts", "secretsmanager"]

  # Sources allowed to reach the endpoints on 443 (e.g. on-prem + VPC CIDR over VPN).
  allowed_cidr_blocks = ["192.168.0.0/22", "10.10.0.0/24"]

  private_dns_enabled = true
  # region defaults to the provider's current region when omitted.

  tags = {
    Project = "s2s-vpn-lab"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `app_name` | Application/environment name used to prefix and tag all resources. | `string` | n/a | yes |
| `vpc_id` | ID of the VPC in which the endpoints and shared security group are created. | `string` | n/a | yes |
| `subnet_ids` | Subnet IDs in which to place endpoint ENIs (one ENI per subnet per service). Min 1. | `list(string)` | n/a | yes |
| `service_names` | Short AWS service names (e.g. `["sts","secretsmanager"]`). Min 1. | `list(string)` | n/a | yes |
| `allowed_cidr_blocks` | CIDR blocks permitted on TCP 443. Min 1; each must be a valid CIDR. | `list(string)` | n/a | yes |
| `private_dns_enabled` | Associate private DNS so the service's default name resolves to the endpoint ENIs. | `bool` | `true` | no |
| `region` | Region used to build endpoint service names. When `null`, the provider's current region is used. | `string` | `null` | no |
| `tags` | Additional tags merged onto all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `security_group_id` | ID of the shared security group attached to every interface endpoint. |
| `endpoint_ids` | Map of short service name => VPC endpoint ID. |
| `endpoint_dns_entries` | Map of short service name => the endpoint's `dns_entry` list (each entry has `dns_name` and `hosted_zone_id`). |
