# AWS Lightsail Instance Terraform Module

Terraform module which creates a Lightsail instance for single-server deployment with static IP, SSH key pair, and firewall rules.

AWS credentials for the instance are provided by the **Lightsail instance role** (`AmazonLightsailInstanceRole`) — the caller attaches the necessary IAM policies to that role directly.

## Features

This module supports creating:

- **Lightsail Instance** - Ubuntu server with configurable plan size
- **Static IP** - Permanent public IP that persists across stop/start
- **SSH Key Pair** - Optional key pair created from your public key
- **Firewall Rules** - Caller-defined port rules (SSH, HTTP, HTTPS, etc.)

## Usage

### Example 1: Web instance with SSH + HTTP/HTTPS

```terraform
module "lightsail" {
  source = "../../modules/lightsail"

  app_name  = "${var.environment}-${var.app_name}"
  region    = "ap-northeast-1"
  bundle_id = "medium_3_2" # 4GB RAM, $24/month

  key_pair_name = "deployer"
  public_key    = var.ssh_public_key

  port_rules = [
    { protocol = "tcp", from_port = 22,  to_port = 22,  cidrs = var.allowed_ssh_cidrs },
    { protocol = "tcp", from_port = 80,  to_port = 80,  cidrs = var.allowed_http_https_cidrs },
    { protocol = "tcp", from_port = 443, to_port = 443, cidrs = var.allowed_http_https_cidrs },
  ]

  tags = local.tags
}
```

### Example 2: DB instance (SSH only — no HTTP exposure)

```terraform
module "lightsail_db" {
  source = "../../modules/lightsail"

  app_name  = "${var.environment}-${var.app_name}-db"
  bundle_id = "nano_3_2" # 512MB RAM, $5/month

  key_pair_name = "deployer"
  public_key    = var.ssh_public_key

  port_rules = [
    { protocol = "tcp", from_port = 22, to_port = 22, cidrs = var.allowed_ssh_cidrs },
  ]

  tags = local.tags
}
```

### Example 3: With Cloud-Init User Data

```terraform
module "lightsail" {
  source = "../../modules/lightsail"

  app_name  = "${var.environment}-${var.app_name}"
  bundle_id = "medium_3_2"

  key_pair_name = "deployer"
  public_key    = var.ssh_public_key

  port_rules = [
    { protocol = "tcp", from_port = 22,  to_port = 22,  cidrs = ["10.0.0.0/8"] },
    { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"] },
  ]

  user_data = <<-EOF
    #!/bin/bash
    apt update && apt upgrade -y
    apt install -y docker.io docker-compose-v2 nginx
    systemctl enable docker nginx
  EOF

  tags = local.tags
}
```

## Lightsail Bundle Reference

| Bundle ID     | RAM   | vCPUs | Storage | Transfer | Price   |
| ------------- | ----- | ----- | ------- | -------- | ------- |
| `nano_3_2`    | 512MB | 2     | 20 GB   | 1 TB     | $5/mo   |
| `micro_3_2`   | 1 GB  | 2     | 40 GB   | 2 TB     | $7/mo   |
| `small_3_2`   | 2 GB  | 2     | 60 GB   | 3 TB     | $12/mo  |
| `medium_3_2`  | 4 GB  | 2     | 80 GB   | 4 TB     | $24/mo  |
| `large_3_2`   | 8 GB  | 2     | 160 GB  | 5 TB     | $44/mo  |
| `xlarge_3_2`  | 16 GB | 4     | 320 GB  | 6 TB     | $88/mo  |
| `2xlarge_3_2` | 32 GB | 8     | 640 GB  | 7 TB     | $176/mo |

> **Recommendation**: `medium_3_2` (4GB/$24) for running Docker (Django + Celery). `nano_3_2` ($5) for a DB-only instance running PostgreSQL + Redis natively.

## SSH Connection

```bash
# Connect using the output ssh_config
ssh <app-name>-server

# Or directly
ssh -i ~/.ssh/deployer.pem ubuntu@<static-ip>
```

## IAM / AWS Credentials

This module does **not** create IAM users or access keys. AWS credentials on the instance
are provided by the `AmazonLightsailInstanceRole` that Lightsail auto-attaches. The caller
is responsible for attaching the required managed policies to that role:

```terraform
data "aws_iam_role" "lightsail_instance_role" {
  name = "AmazonLightsailInstanceRole"
}

resource "aws_iam_policy" "my_policy" {
  name   = "my-app-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "my_policy" {
  role       = data.aws_iam_role.lightsail_instance_role.name
  policy_arn = aws_iam_policy.my_policy.arn
}
```

## Inputs

| Name                     | Description                                               | Type           | Default            | Required |
| ------------------------ | --------------------------------------------------------- | -------------- | ------------------ | :------: |
| app_name                 | Application name for resource naming                      | `string`       | n/a                |   yes    |
| region                   | AWS region for the Lightsail instance                     | `string`       | `"ap-northeast-1"` |    no    |
| availability_zone_suffix | AZ suffix appended to region                              | `string`       | `"a"`              |    no    |
| blueprint_id             | Lightsail OS blueprint                                    | `string`       | `"ubuntu_24_04"`   |    no    |
| bundle_id                | Lightsail instance plan                                   | `string`       | `"medium_3_2"`     |    no    |
| key_pair_name            | SSH key pair name (null = skip creation)                  | `string`       | `null`             |    no    |
| public_key               | SSH public key content (required if key_pair_name is set) | `string`       | `""`               |    no    |
| user_data                | Cloud-init script to run on first boot                    | `string`       | `null`             |    no    |
| port_rules               | List of Lightsail firewall port rules                     | `list(object)` | `[]`               |    no    |
| tags                     | Tags to apply to all resources                            | `map(string)`  | `{}`               |    no    |

## Outputs

| Name          | Description                                                 |
| ------------- | ----------------------------------------------------------- |
| instance_name | Name of the Lightsail instance                              |
| instance_arn  | ARN of the Lightsail instance                               |
| public_ip     | Public IP (changes on stop/start — use `static_ip` instead) |
| private_ip    | Private IP of the Lightsail instance                        |
| static_ip     | Static IP attached to the instance (does not change)        |
| key_pair_name | Name of the Lightsail key pair (if created)                 |
| ssh_config    | SSH config entry — add to `~/.ssh/config`                   |

## Security Notes

1. **SSH Restriction**: Always set `cidrs` in SSH port rule to specific IPs — avoid `0.0.0.0/0` in production
2. **AWS Credentials**: Use `AmazonLightsailInstanceRole` — no static access keys on disk
3. **Firewall**: Only declare ports you need — all other inbound traffic is blocked by default
4. **Key Pair**: Public key only — private key never leaves your machine

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |
