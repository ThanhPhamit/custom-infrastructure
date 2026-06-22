# ec2_instance

A single, reusable EC2 instance with its own security group, optional Elastic IP,
and optional extra EBS data volume. IMDSv2 is enforced and EBS volumes are encrypted
by default.

Unlike `bastion_host` (bastion-only: SG opens 22 only, instance profile SSM-only),
this module takes **caller-supplied `ingress_rules`** (any ports, CIDR **or** source
security-group) and a **caller-supplied `iam_instance_profile`** — so it works for web
servers, app servers, databases, etc.

## Usage

```hcl
# Web box: public, 22/80/443, EIP, app instance profile
module "web" {
  source = "../../modules/ec2_instance"

  app_name                    = "tokyo-staging-hinerism-web"
  ami_id                      = data.aws_ami.ubuntu2004.id
  instance_type               = "t3.medium"
  vpc_id                      = module.network.vpc_id
  subnet_id                   = module.network.public_subnet_ids[0]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  create_eip                  = true
  iam_instance_profile        = aws_iam_instance_profile.web.name

  ingress_rules = [
    { description = "SSH (office)", from_port = 22, to_port = 22, cidr_blocks = var.allowed_ssh_cidrs },
    { description = "HTTP", from_port = 80, to_port = 80, cidr_blocks = ["0.0.0.0/0"] },
    { description = "HTTPS", from_port = 443, to_port = 443, cidr_blocks = ["0.0.0.0/0"] },
  ]

  tags = local.tags
}

# DB box: datastore ports only from the web SG, separate data volume
module "db" {
  source = "../../modules/ec2_instance"

  app_name             = "tokyo-staging-hinerism-db"
  ami_id               = data.aws_ami.ubuntu2004.id
  instance_type        = "t3.small"
  vpc_id               = module.network.vpc_id
  subnet_id            = module.network.public_subnet_ids[0]
  key_name             = aws_key_pair.deployer.key_name
  iam_instance_profile = aws_iam_instance_profile.db.name

  ingress_rules = [
    { description = "SSH (office)", from_port = 22, to_port = 22, cidr_blocks = var.allowed_ssh_cidrs },
    { description = "MySQL from web", from_port = 3306, to_port = 3306, source_security_group_id = module.web.security_group_id },
    { description = "Redis from web", from_port = 6379, to_port = 6379, source_security_group_id = module.web.security_group_id },
    { description = "Memcached from web", from_port = 11211, to_port = 11211, source_security_group_id = module.web.security_group_id },
  ]

  create_data_volume = true
  data_volume_size   = 40
  data_volume_device = "/dev/sdf"

  tags = local.tags
}
```

## Inputs (key)

| Name | Description | Default |
|------|-------------|---------|
| `app_name` | Full instance name / Name tag | — (required) |
| `ami_id` | AMI to launch | — (required) |
| `instance_type` | e.g. `t3.medium` | — (required) |
| `vpc_id` / `subnet_id` | Placement | — (required) |
| `key_name` | EC2 key pair for SSH | `null` |
| `associate_public_ip_address` | Auto public IP at launch | `false` |
| `create_eip` | Attach a stable Elastic IP | `false` |
| `iam_instance_profile` | Instance profile name (app AWS access) | `null` |
| `ingress_rules` | List of objects (CIDR or source-SG) | `[]` |
| `egress_cidr_blocks` | All-protocol egress | `["0.0.0.0/0"]` |
| `root_volume_size` / `_type` / `_encrypted` | Root EBS | `30` / `gp3` / `true` |
| `create_data_volume` + `data_volume_*` | Extra EBS volume | `false` |
| `user_data` | cloud-init bootstrap | `null` |
| `tags` | Tag map | `{}` |

## Outputs

`instance_id`, `instance_arn`, `private_ip`, `public_ip` (EIP if created), `availability_zone`,
`security_group_id`, `data_volume_id`.
