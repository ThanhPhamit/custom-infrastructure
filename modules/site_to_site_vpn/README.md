# site_to_site_vpn

AWS side of a Site-to-Site IPsec VPN. Provisions a Virtual Private Gateway (attached to the VPC),
a Customer Gateway for the on-prem peer, and a static-routing VPN connection whose **both** tunnels
are pinned to a single hardened IKEv2 proposal set (encryption / integrity / DH group) with Dead
Peer Detection. It adds the on-prem static route, enables VGW route propagation on caller-supplied
route tables, and optionally creates one CloudWatch `TunnelState` alarm per tunnel.

The on-prem device is out of scope — Terraform drives it only through the tunnel address / PSK
outputs, which must be mirrored exactly in the on-prem IPsec config or the tunnels will not negotiate.

## Usage

```hcl
module "s2s_vpn" {
  source = "../../modules/site_to_site_vpn"

  app_name            = "s2s-vpn-lab"
  vpc_id              = module.network.vpc_id
  customer_gateway_ip = "139.180.223.198" # on-prem public IP
  onprem_cidr         = "10.100.0.0/24"

  # Propagate the on-prem route onto the private route tables.
  route_table_ids = module.network.private_route_table_ids

  # Pinned IPsec proposals (defaults shown; mirror these on-prem).
  tunnel_ike_versions                  = ["ikev2"]
  tunnel_phase1_encryption_algorithms  = ["AES256"]
  tunnel_phase2_encryption_algorithms  = ["AES256"]
  tunnel_phase1_integrity_algorithms   = ["SHA2-256"]
  tunnel_phase2_integrity_algorithms   = ["SHA2-256"]
  tunnel_phase1_dh_group_numbers       = [20]
  tunnel_phase2_dh_group_numbers       = [20]
  tunnel_dpd_timeout_action            = "restart"

  # Optional observability.
  enable_tunnel_state_alarms = true
  alarm_actions              = [aws_sns_topic.vpn_alerts.arn]

  tags = {
    Project = "s2s-vpn-lab"
    Env     = "lab"
  }
}

# PSKs are sensitive; never paste into chat or commit cleartext.
output "vpn_tunnel1_preshared_key" {
  value     = module.s2s_vpn.tunnel1_preshared_key
  sensitive = true
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | `string` | _required_ | Name prefix for every resource and the `Name` tag. |
| `vpc_id` | `string` | _required_ | VPC the VGW attaches to. |
| `customer_gateway_ip` | `string` | _required_ | On-prem public IPv4 (IPsec peer). |
| `customer_gateway_bgp_asn` | `number` | `65000` | Customer gateway BGP ASN (informational under static routing). |
| `amazon_side_asn` | `number` | `64512` | Amazon-side BGP ASN for the VGW. |
| `onprem_cidr` | `string` | _required_ | On-prem CIDR; added as the static VPN route. |
| `route_table_ids` | `list(string)` | `[]` | Route tables to enable VGW propagation on. |
| `tunnel_ike_versions` | `list(string)` | `["ikev2"]` | Permitted IKE versions (both tunnels). |
| `tunnel_phase1_encryption_algorithms` | `list(string)` | `["AES256"]` | Phase 1 encryption algorithms (both tunnels). |
| `tunnel_phase2_encryption_algorithms` | `list(string)` | `["AES256"]` | Phase 2 encryption algorithms (both tunnels). |
| `tunnel_phase1_integrity_algorithms` | `list(string)` | `["SHA2-256"]` | Phase 1 integrity algorithms (both tunnels). |
| `tunnel_phase2_integrity_algorithms` | `list(string)` | `["SHA2-256"]` | Phase 2 integrity algorithms (both tunnels). |
| `tunnel_phase1_dh_group_numbers` | `list(number)` | `[20]` | Phase 1 DH group numbers (both tunnels). |
| `tunnel_phase2_dh_group_numbers` | `list(number)` | `[20]` | Phase 2 DH group numbers (both tunnels). |
| `tunnel_dpd_timeout_action` | `string` | `"restart"` | DPD timeout action: `clear` / `none` / `restart`. |
| `enable_tunnel_state_alarms` | `bool` | `false` | Create one CloudWatch `TunnelState` alarm per tunnel. |
| `alarm_actions` | `list(string)` | `[]` | SNS topic ARNs for ALARM/OK transitions. |
| `tags` | `map(string)` | `{}` | Extra tags merged onto every taggable resource. |

## Outputs

| Name | Sensitive | Description |
|------|-----------|-------------|
| `vpn_gateway_id` | no | Virtual Private Gateway ID. |
| `customer_gateway_id` | no | Customer Gateway ID. |
| `vpn_connection_id` | no | Site-to-Site VPN connection ID. |
| `tunnel1_address` | no | AWS public IP for tunnel 1. |
| `tunnel2_address` | no | AWS public IP for tunnel 2. |
| `tunnel1_preshared_key` | yes | Pre-shared key for tunnel 1 (mirror on-prem). |
| `tunnel2_preshared_key` | yes | Pre-shared key for tunnel 2 (mirror on-prem). |
