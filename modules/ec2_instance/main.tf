# =============================================================================
# Security group — built from caller-supplied ingress_rules (CIDR or source-SG).
# Egress: caller-supplied egress_rules if given (port-restricted), else all-protocol
# to egress_cidr_blocks. create_before_destroy so it can be replaced in place.
# =============================================================================
locals {
  egress = length(var.egress_rules) > 0 ? var.egress_rules : [{
    description = "All outbound (apt / S3 / Secrets Manager / CloudWatch / certbot / SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidr_blocks
  }]
}

resource "aws_security_group" "this" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups = ingress.value.source_security_group_id != null ? [ingress.value.source_security_group_id] : null
    }
  }

  dynamic "egress" {
    for_each = local.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-sg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# The EC2 instance. IMDSv2 required (http_tokens = "required") to block SSRF
# credential theft; root volume encrypted by default.
# =============================================================================
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = var.associate_public_ip_address
  ebs_optimized               = var.ebs_optimized
  user_data                   = var.user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.root_volume_encrypted
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    # IMDSv2 enforced by default ("required"). Set "optional" only for legacy SDKs that
    # cannot do the IMDSv2 token handshake (e.g. boto 2.x) and must fall back to IMDSv1.
    http_tokens                 = var.metadata_http_tokens
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name      = var.app_name
    ManagedBy = "Terraform"
  })

  # Don't let a newer source AMI (e.g. data.aws_ami most_recent) silently force a
  # destroy/recreate of a live instance — that would detach data volumes. Roll AMIs
  # deliberately (bump ami_id + planned replace), not as drift.
  lifecycle {
    ignore_changes = [ami]
  }
}

# =============================================================================
# Optional Elastic IP — a stable public address (DNS A record / TLS).
# =============================================================================
resource "aws_eip" "this" {
  count    = var.create_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = merge(var.tags, {
    Name      = "${var.app_name}-eip"
    ManagedBy = "Terraform"
  })
}

# =============================================================================
# Optional separate data volume (e.g. mounted at /var/lib/mysql). Lives in the
# instance's AZ so it can attach. Encrypted by default.
# =============================================================================
resource "aws_ebs_volume" "data" {
  count             = var.create_data_volume ? 1 : 0
  availability_zone = aws_instance.this.availability_zone
  size              = var.data_volume_size
  type              = var.data_volume_type
  encrypted         = var.data_volume_encrypted

  tags = merge(var.tags, {
    Name      = "${var.app_name}-data"
    ManagedBy = "Terraform"
  })
}

resource "aws_volume_attachment" "data" {
  count       = var.create_data_volume ? 1 : 0
  device_name = var.data_volume_device
  volume_id   = aws_ebs_volume.data[0].id
  instance_id = aws_instance.this.id
}
