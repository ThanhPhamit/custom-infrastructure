# Network Module - Sample Usage

## main.tf

```terraform
module "bastion_host" {
  source = "../modules/bastion_host"

  app_name                = "${var.environment}-${var.app_name}"
  ami_id                  = var.bastion_ami_id
  vpc_id                  = var.vpc_id
  subnet_id               = var.public_subnet_ids[0]
  instance_type           = var.bastion_instance_type
  key_pair_name           = var.bastion_key_pair_name
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
  create_eip              = var.create_bastion_eip
  root_volume_size        = 8

  # Enable EventBridge + Lambda scheduler
  enable_scheduler = true
  # scheduler_start_cron = "cron(0 0 ? * MON-FRI *)"  # 7AM GMT+7
  # scheduler_stop_cron  = "cron(0 15 ? * MON-FRI *)" # 10PM GMT+7
  scheduler_start_cron = "cron(0 0 ? * * *)"  # 7AM GMT+7
  scheduler_stop_cron  = "cron(0 15 ? * * *)" # 10PM GMT+7

  tags = local.tags
}

```

## variables.tf

```terraform
variable "bastion_ami_id" {
  description = "AMI ID for the bastion host EC2 instance"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_pair_name" {
  description = "Name of the EC2 Key Pair for bastion host SSH access"
  type        = string
}

variable "create_bastion_eip" {
  description = "Whether to create an Elastic IP for the bastion host"
  type        = bool
  default     = true
}
variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the bastion host"
  type        = list(string)
}

```

## terraform.tfvars

```hcl
bastion_ami_id        = "ami-00da6ca695594e43b"
bastion_instance_type = "t3.micro"
bastion_key_pair_name = "lg-keypair"
create_bastion_eip    = true
allowed_ssh_cidr_blocks = [
  "115.78.131.125/32", # Lion Garden Office IP
  "54.95.206.164/32",  # LG VPN endpoint,
  "15.168.63.48/32",   # Ms.Nhu,
  "15.168.179.72/32",  # Mr.Van
]
```

## Outputs

```terraform

```
