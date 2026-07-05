# route53_resolver_outbound

Creates a **Route 53 Resolver OUTBOUND endpoint** + a **forwarding rule** so workloads inside the
VPC can resolve names owned by an on-prem DNS server (e.g. `db.onprem.lab`) over a Site-to-Site
VPN. The mirror of `route53_resolver_inbound`: inbound lets on-prem ask AWS; outbound lets AWS ask
on-prem.

The VPC's native resolver (`VPC CIDR +2`) holds no on-prem zones and cannot originate queries
outside the VPC by itself — this endpoint (2 ENIs) plus a FORWARD rule ("domain X → ask on-prem
DNS at ip:53") is the supported way out. **No copies are held in AWS**: every answer comes live
from the authoritative on-prem DNS.

## What it builds

- One outbound endpoint with **one ENI per subnet** in `subnet_ids` (AWS requires ≥ 2). Pin the
  ENI IPs via `ip_addresses` — forwarded queries arrive at the on-prem DNS **from** these IPs, so
  stable values let the on-prem firewall allow-list them.
- An egress-only **security group** (DNS 53 udp+tcp to `target_dns_ips` only; no ingress).
- A **FORWARD rule** for `forward_domain` targeting `target_dns_ips:target_dns_port`, associated
  with the VPC.

## Alternatives & trade-offs (read before assuming you need this)

This endpoint costs ~$0.125/ENI-hour (**≈ $182/month** for the minimum 2 ENIs). Cheap substitutes
exist — whether they are acceptable comes down to one question:

> **Who owns the stability of the IP behind the name?**
> For this (outbound) direction the target IPs are usually **yours and static** (you assigned the
> on-prem LAN addresses) — which makes the substitutes below far more defensible than their
> inbound-side counterparts.

| Substitute | Cost | What you keep | What you give up |
|---|---|---|---|
| **Direct IP** in client config (`PGHOST=10.100.0.1`) | $0 | Zero moving parts, nothing to debug | No name → no TLS hostname verification; IP baked into every consumer; scales to a handful of targets at best |
| **Private hosted zone** with a manually-managed A record (`db.onprem.lab → 10.100.0.1`) | ~$0.50/mo | A stable NAME (TLS-verifiable, single place to update), Terraform-managed record | It is a **manually-synced COPY** of on-prem truth — rots if on-prem changes without telling you; cannot mirror dynamic zones (AD/DHCP registrations) or another team's namespace |
| **This module** (live forwarding) | ~$182/mo | **No copies**: on-prem DNS stays authoritative; AWS follows every change automatically; scales to AD, wildcards, thousands of dynamic records, org-wide (rules shareable via RAM) | Standing ENI cost + one more hop to reason about during DNS incidents |

**Rule of thumb:** pay for the outbound endpoint when the answers' truth lives on-prem AND you do
**not** control its churn — many/dynamic records (Active Directory is the canonical case) or a
namespace owned by another team. For 1–2 static, self-owned IPs, direct IP or a private-hosted-zone
copy is legitimate production practice.

The mirror decision exists on the inbound side (`route53_resolver_inbound`): there the IPs are
**AWS-owned and volatile** (RDS failover/maintenance), so the cheap substitutes rot on AWS's
schedule — see that module's README for the mirrored table.

## On-prem integration

- Run a DNS server on-prem that is **authoritative** for `forward_domain` — e.g. dnsmasq:
  `listen-address=10.100.0.1` + `address=/db.onprem.lab/10.100.0.1`.
- Firewall: allow UDP/TCP 53 **from** `resolver_outbound_ip_addresses` (over the tunnel) to the
  DNS server.

## Usage

```hcl
module "resolver_outbound" {
  source = "../../modules/route53_resolver_outbound"

  app_name   = "s2s-vpn-lab"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets # >= 2

  # Pin ENI IPs so the on-prem firewall can allow-list stable sources.
  ip_addresses = ["192.168.0.11", "192.168.1.11"]

  forward_domain = "onprem.lab" # never .local (mDNS, RFC 6762)
  target_dns_ips = ["10.100.0.1"]

  tags = local.tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `app_name` | Name prefix for every resource + Name tag. | `string` | n/a | yes |
| `vpc_id` | VPC for the endpoint, SG, and rule association. | `string` | n/a | yes |
| `subnet_ids` | Subnets for the outbound ENIs (≥ 2 required by AWS). | `list(string)` | n/a | yes |
| `ip_addresses` | Optional fixed ENI IPs (positional to `subnet_ids`). | `list(string)` | `[]` | no |
| `forward_domain` | Domain forwarded to on-prem DNS (not `.local`). | `string` | n/a | yes |
| `target_dns_ips` | On-prem DNS server IPs. | `list(string)` | n/a | yes |
| `target_dns_port` | On-prem DNS port. | `number` | `53` | no |
| `tags` | Extra tags merged onto everything. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `resolver_endpoint_id` / `resolver_endpoint_arn` | Outbound endpoint identifiers. |
| `resolver_outbound_ip_addresses` | Sorted ENI IPs — allow-list these in the on-prem firewall. |
| `forward_rule_id` | Forwarding rule ID. |
| `security_group_id` | The endpoint's egress-only SG. |
