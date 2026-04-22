# AWS Route 53 DNS Records Terraform Module

Terraform module which creates Route 53 A records pointing multiple subdomains to a single IP address. Designed for single-server deployments where patient, clinic, and API domains all resolve to the same Lightsail/EC2 instance.

## Features

This module supports creating:

- **Route 53 A Records** - Multiple subdomains → single target IP
- **Automatic Zone Lookup** - Finds zone ID from zone name
- **Configurable TTL** - Per-deployment TTL control

## Usage

### Example 1: Care Hub Single-Server (3 Subdomains)

```terraform
module "dns" {
  source = "../../modules/lightsail_dns"

  dns_zone   = "care-hub.lion-garden.com"
  target_ip  = module.lightsail.static_ip

  subdomains = [
    "patient.dev.care-hub.lion-garden.com",
    "clinic.dev.care-hub.lion-garden.com",
    "api.dev.care-hub.lion-garden.com",
  ]
}
```

### Example 2: Single Domain

```terraform
module "dns" {
  source = "../../modules/lightsail_dns"

  dns_zone   = "example.com"
  target_ip  = "13.230.100.50"

  subdomains = [
    "app.example.com",
  ]

  ttl = 3600 # 1 hour cache
}
```

### Example 3: Staging with Wildcard-like Coverage

```terraform
module "dns" {
  source = "../../modules/lightsail_dns"

  dns_zone   = "care-hub.lion-garden.com"
  target_ip  = module.lightsail.static_ip

  subdomains = [
    "patient.stg.care-hub.lion-garden.com",
    "clinic.stg.care-hub.lion-garden.com",
    "api.stg.care-hub.lion-garden.com",
    "admin.stg.care-hub.lion-garden.com",
  ]

  ttl = 600
}
```

## How It Works

```
                     Route 53 Zone
                 care-hub.lion-garden.com
                          │
           ┌──────────────┼──────────────┐
           │              │              │
     patient.dev.*   clinic.dev.*   api.dev.*
           │              │              │
           └──────────────┼──────────────┘
                          │
                    A Record → IP
                          │
                  ┌───────▼────────┐
                  │  Lightsail     │
                  │  Static IP     │
                  │  13.230.x.x    │
                  └────────────────┘
                          │
                  Nginx routes by Host header:
                  patient.* → Vue patient build
                  clinic.*  → Vue clinic build
                  api.*     → Django :8000
```

## Inputs

| Name       | Description                                     | Type           | Default | Required |
| ---------- | ----------------------------------------------- | -------------- | ------- | :------: |
| dns_zone   | Route 53 hosted zone name (e.g., `example.com`) | `string`       | n/a     |   yes    |
| subdomains | List of FQDNs to point to the target IP         | `list(string)` | n/a     |   yes    |
| target_ip  | IP address to point DNS records to              | `string`       | n/a     |   yes    |
| ttl        | DNS record TTL in seconds                       | `number`       | `300`   |    no    |

## Outputs

| Name        | Description                                     |
| ----------- | ----------------------------------------------- |
| dns_records | Map of subdomain → FQDN for created DNS records |
| zone_id     | Route 53 zone ID used                           |

## DNS Propagation

After `terraform apply`, DNS records may take up to the TTL duration to propagate globally. Verify with:

```bash
# Check individual records
dig +short patient.dev.care-hub.lion-garden.com
dig +short clinic.dev.care-hub.lion-garden.com
dig +short api.dev.care-hub.lion-garden.com

# All should return the same Lightsail static IP
```

## Prerequisites

- Route 53 hosted zone must already exist for the specified `dns_zone`
- The target IP should be a static/elastic IP (not a dynamic one that changes on reboot)

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
