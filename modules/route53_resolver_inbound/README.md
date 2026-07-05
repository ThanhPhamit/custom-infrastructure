# route53_resolver_inbound

Creates a **Route 53 Resolver INBOUND endpoint** so on-prem DNS servers can resolve AWS private
names (private hosted zones and the regional `*.rds.amazonaws.com`, `secretsmanager.*`, `sts.*`
service endpoints) by forwarding queries into the VPC over a Site-to-Site IPsec VPN.

The VPC's native resolver (`VPC CIDR +2` / `169.254.169.253`) is **not reachable from on-prem over
Site-to-Site VPN** — this inbound endpoint is the supported way to expose DNS to the on-prem side.

## What it builds

- One inbound endpoint with **one ENI (`ip_address` block) per subnet** in `subnet_ids`
  (AWS requires at least two for availability). Each ENI may use a fixed private IP from
  `ip_addresses` (matched positionally to `subnet_ids`) or an auto-assigned one.
- A locked-down **security group**: ingress DNS (UDP **and** TCP port 53) from
  `allowed_cidr_blocks` (the on-prem CIDR) only; egress DNS (UDP/TCP 53) to `vpc_cidr` only.
- Optional **Resolver query logging** to a CloudWatch log group, associated with the VPC
  (toggle with `enable_query_logging`).

## On-prem integration

Point on-prem DNS forwarders for the AWS private zones at the endpoint's ENI IPs
(`resolver_inbound_ip_addresses` output). Typically forward these zones over the VPN:

- `*.<region>.rds.amazonaws.com` (Aurora / RDS private endpoints)
- `secretsmanager.<region>.amazonaws.com`
- `sts.<region>.amazonaws.com`

## Usage

```hcl
module "resolver_inbound" {
  source = "../../modules/route53_resolver_inbound"

  app_name            = "s2s-vpn-lab"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids # >= 2 subnets
  vpc_cidr            = "192.168.0.0/22"
  allowed_cidr_blocks = ["10.10.0.0/16"] # on-prem network behind the VPN

  # Optional: pin ENI IPs (positional to subnet_ids); omit for auto-assignment.
  ip_addresses = ["192.168.0.10", "192.168.1.10"]

  enable_query_logging     = true
  query_log_retention_days = 14

  tags = {
    Environment = "lab"
    Project     = "s2s-vpn-lab"
  }
}
```

## Alternatives & trade-offs (read before assuming you need this)

This endpoint costs ~$0.125/ENI-hour (**≈ $182/month** for the minimum 2 ENIs). A $0 substitute
exists — whether it is acceptable comes down to one question:

> **Who owns the stability of the IP behind the name?**
> For this (inbound) direction the answers live on the **AWS side** — RDS/endpoint private IPs are
> assigned by AWS and **change on AWS's schedule** (failover, maintenance, instance replacement).
> Any copy you make rots the day AWS moves the target.

| Substitute | Cost | What you keep | What you give up |
|---|---|---|---|
| `/etc/hosts` on the on-prem host pinning `cluster-xxx.<region>.rds.amazonaws.com` → its *current* private IP | $0 | **`sslmode=verify-full` still works** — TLS verifies the cert against the name you *typed*, not against how it was resolved | The pinned IP is **AWS-owned and volatile**: on failover/maintenance the copy silently rots and connections fail **closed** (timeout) until a human re-pins. No wildcards; per-host manual state. |
| Same hosts-file trick for the STS / Secrets Manager interface-endpoint IPs | $0 | Endpoint ENI IPs are stable for the endpoint's lifetime | Breaks silently if the endpoint is ever recreated; still per-host manual state |
| Raw private IP in the client config (no name at all) | $0 | Nothing else | **Breaks `verify-full`** (certs carry DNS names, not IPs) *and* rots on IP change — worst of both |

**Rule of thumb:** pay for the inbound endpoint when the authoritative answers live on the other
side and you do **not** own the IPs' stability — for RDS names that is *always* true. The
hosts-file shortcut is defensible only for a short-lived demo where a stale pin costs a re-edit,
not an outage.

The mirror decision exists on the outbound side (`route53_resolver_outbound`): there the target
IPs are usually **yours and static**, so the cheap substitutes (direct IP, private hosted zone)
are far more defensible — see that module's README for the mirrored table.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `app_name` | Name prefix applied to every resource name and the `Name` tag. | `string` | n/a | yes |
| `vpc_id` | VPC the endpoint, security group, and query-log association live in. | `string` | n/a | yes |
| `subnet_ids` | Subnets for the resolver ENIs — one ENI per subnet; **>= 2** required. | `list(string)` | n/a | yes |
| `allowed_cidr_blocks` | Source CIDR(s) allowed to query DNS (the on-prem CIDR). | `list(string)` | n/a | yes |
| `vpc_cidr` | VPC CIDR — egress DNS destination for the ENIs. | `string` | n/a | yes |
| `ip_addresses` | Optional fixed ENI IPs, matched positionally to `subnet_ids`; extras auto-assigned. | `list(string)` | `[]` | no |
| `enable_query_logging` | Create the query-log config, log group, and VPC association. | `bool` | `true` | no |
| `query_log_retention_days` | Retention (days) for the query-log CloudWatch log group. | `number` | `14` | no |
| `tags` | Additional tags merged onto every taggable resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `resolver_endpoint_id` | ID of the Route 53 Resolver inbound endpoint. |
| `resolver_endpoint_arn` | ARN of the Route 53 Resolver inbound endpoint. |
| `resolver_inbound_ip_addresses` | Private IPs of the resolver ENIs — on-prem DNS forwards to these. |
| `security_group_id` | ID of the security group attached to the endpoint. |
| `query_log_group_name` | CloudWatch log group name for query logs, or `null` when disabled. |
