# AWS Bastion Host Terraform Module

Terraform module which creates a bastion host (jump server) on AWS with optional automatic scheduling.

## Features

This module supports creating:

- **EC2 Instance** - Bastion host for secure SSH access
- **Security Group** - SSH access control with CIDR restrictions
- **Elastic IP** - Optional static public IP address
- **IAM Role** - Instance profile with SSM permissions
- **EventBridge Scheduler** - Optional automatic start/stop scheduling
- **Lambda Function** - For scheduled instance management

## Subnet Placement: Public vs Private (read before choosing `subnet_id`)

Prefer a **private subnet**, but only when the VPC lets the SSM agent reach the
`ssm`, `ssmmessages`, and `ec2messages` services. Check the target subnet's
route table and the VPC's endpoints first, then pick the row that matches:

| VPC capability                                                              | Placement          | Module settings                                                 |
| --------------------------------------------------------------------------- | ------------------ | --------------------------------------------------------------- |
| Private subnet routes `0.0.0.0/0` to a NAT gateway                          | Private (preferred) | `associate_public_ip_address = false`, `create_eip = false`     |
| VPC has interface endpoints for `ssm` + `ssmmessages` + `ec2messages` (all 3) | Private (preferred) | `associate_public_ip_address = false`, `create_eip = false`     |
| Neither NAT nor the 3 SSM interface endpoints                               | Public (fallback)  | `associate_public_ip_address = true`, keep `enable_ssh = false` |

Important caveats:

- An **S3 gateway endpoint alone is NOT sufficient** for Session Manager. It only
  covers optional features (agent auto-update, session logs to S3, Patch Manager).
  Without NAT or the 3 interface endpoints, the agent cannot register and the
  instance never appears in Session Manager.
- The public-subnet fallback is acceptable in practice: with `enable_ssh = false`
  the security group has zero inbound rules, so the public IP is used for
  outbound SSM traffic only. Compliance scanners (e.g. CIS) may still flag
  "EC2 instance with public IP" — prefer private when the prerequisites exist.
- If the bastion must reach on-prem/customer networks via VGW/TGW, verify the
  chosen subnet's route table also has those routes (route propagation enabled).
- Rough cost: 3 interface endpoints ≈ $25–30/month (1 AZ, ap-northeast-3);
  NAT gateway ≈ $45/month + data processing. A public IP on a scheduler-stopped
  bastion costs only a few dollars/month.
- SSH mode (`enable_ssh = true`) requires a public subnet + public IP (or VPN
  reachability); the SSM decision table above does not apply.

Quick checks:

```bash
# Does the subnet route 0.0.0.0/0 to a NAT gateway?
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<subnet-id>" \
  --query 'RouteTables[].Routes'

# Does the VPC have the 3 SSM interface endpoints?
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'VpcEndpoints[].ServiceName'
```

## Usage

### Example 1: Basic Bastion Host

```terraform
module "bastion_host" {
  source = "../../modules/bastion_host"

  app_name                = "${var.environment}-${var.app_name}"
  ami_id                  = var.bastion_ami_id
  vpc_id                  = module.network.vpc_id
  subnet_id               = module.network.public_subnets[0]
  instance_type           = "t3.micro"
  key_pair_name           = var.bastion_key_pair_name
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
  create_eip              = true
  root_volume_size        = 8

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 2: Bastion with Scheduler (Cost Optimization)

```terraform
module "bastion_host" {
  source = "../../modules/bastion_host"

  app_name                = "${var.environment}-${var.app_name}"
  ami_id                  = var.bastion_ami_id
  vpc_id                  = module.network.vpc_id
  subnet_id               = module.network.public_subnets[0]
  instance_type           = "t3.micro"
  key_pair_name           = var.bastion_key_pair_name
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
  create_eip              = true
  root_volume_size        = 8

  # Enable EventBridge + Lambda scheduler
  enable_scheduler     = true
  scheduler_start_cron = "cron(0 0 ? * MON-FRI *)"  # 9AM JST (0:00 UTC)
  scheduler_stop_cron  = "cron(0 12 ? * MON-FRI *)" # 9PM JST (12:00 UTC)

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: Bastion without Elastic IP

```terraform
module "bastion_host" {
  source = "../../modules/bastion_host"

  app_name                = "${var.environment}-${var.app_name}"
  ami_id                  = var.bastion_ami_id
  vpc_id                  = module.network.vpc_id
  subnet_id               = module.network.public_subnets[0]
  instance_type           = "t3.micro"
  key_pair_name           = var.bastion_key_pair_name
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
  create_eip              = false  # Use dynamic public IP

  tags = {
    Environment = "development"
    Terraform   = "true"
  }
}
```

## Scheduler Configuration

The scheduler uses EventBridge rules and Lambda to automatically start/stop the bastion host.

| Schedule Type | Cron Expression                  | Description                  |
| ------------- | -------------------------------- | ---------------------------- |
| Weekdays only | `cron(0 0 ? * MON-FRI *)`        | Start at 9AM JST on weekdays |
| Every day     | `cron(0 0 ? * * *)`              | Start at 9AM JST daily       |
| Custom        | `cron(minutes hours ? * days *)` | Custom schedule              |

### Cron Expression Examples (UTC)

| JST Time | UTC Time | Cron Expression      |
| -------- | -------- | -------------------- |
| 7:00 AM  | 22:00    | `cron(0 22 ? * * *)` |
| 9:00 AM  | 0:00     | `cron(0 0 ? * * *)`  |
| 6:00 PM  | 9:00     | `cron(0 9 ? * * *)`  |
| 10:00 PM | 13:00    | `cron(0 13 ? * * *)` |

## SSH Connection Examples

```bash
# Connect to bastion
ssh -i /path/to/your-key.pem ec2-user@<bastion-ip>

# Port forwarding to RDS
ssh -i /path/to/your-key.pem -L 5432:rds-endpoint.region.rds.amazonaws.com:5432 ec2-user@<bastion-ip>

# Port forwarding to Redis
ssh -i /path/to/your-key.pem -L 6379:redis-endpoint.cache.amazonaws.com:6379 ec2-user@<bastion-ip>
```

## Inputs

| Name                    | Description                           | Type           | Default                      | Required |
| ----------------------- | ------------------------------------- | -------------- | ---------------------------- | :------: |
| app_name                | Application name for resource naming  | `string`       | n/a                          |   yes    |
| ami_id                  | AMI ID for the bastion host           | `string`       | n/a                          |   yes    |
| vpc_id                  | VPC ID where bastion will be created  | `string`       | n/a                          |   yes    |
| subnet_id               | Public subnet ID for the bastion host | `string`       | n/a                          |   yes    |
| key_pair_name           | EC2 Key Pair name for SSH access      | `string`       | n/a                          |   yes    |
| allowed_ssh_cidr_blocks | CIDR blocks allowed to SSH            | `list(string)` | n/a                          |   yes    |
| instance_type           | EC2 instance type                     | `string`       | `"t3.micro"`                 |    no    |
| create_eip              | Whether to create an Elastic IP       | `bool`         | `true`                       |    no    |
| root_volume_size        | Root volume size in GB                | `number`       | `8`                          |    no    |
| enable_scheduler        | Enable automatic start/stop scheduler | `bool`         | `false`                      |    no    |
| scheduler_start_cron    | Cron expression for starting instance | `string`       | `"cron(0 0 ? * MON-FRI *)"`  |    no    |
| scheduler_stop_cron     | Cron expression for stopping instance | `string`       | `"cron(0 12 ? * MON-FRI *)"` |    no    |
| tags                    | Tags to apply to resources            | `map(string)`  | `{}`                         |    no    |

## Outputs

| Name                          | Description                                |
| ----------------------------- | ------------------------------------------ |
| bastion_instance_id           | ID of the bastion host instance            |
| bastion_public_ip             | Public IP address of the bastion host      |
| bastion_private_ip            | Private IP address of the bastion host     |
| bastion_security_group_id     | Security group ID of the bastion host      |
| elastic_ip                    | Elastic IP address (if created)            |
| ssh_command                   | SSH command to connect to the bastion host |
| mysql_connection_example      | Example MySQL connection command           |
| scheduler_enabled             | Whether the scheduler is enabled           |
| scheduler_lambda_function_arn | ARN of the scheduler Lambda function       |

## Security Recommendations

1. **Restrict SSH Access**: Only allow specific IP addresses in `allowed_ssh_cidr_blocks`
2. **Use Strong Key Pairs**: Use RSA 4096-bit or Ed25519 key pairs
3. **Enable Scheduler**: Reduce attack surface by stopping bastion when not in use
4. **Regular AMI Updates**: Keep the bastion AMI updated with security patches
5. **Audit Access**: Enable CloudTrail for SSH access logging

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
