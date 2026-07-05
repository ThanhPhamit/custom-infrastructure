locals {
  region = coalesce(var.region, data.aws_region.current.region)
}

################################################################################
# Shared security group for all interface endpoints
################################################################################

resource "aws_security_group" "endpoints" {
  name_prefix = "${var.app_name}-vpce-"
  description = "Allow HTTPS (443) to ${var.app_name} interface VPC endpoints from approved CIDRs."
  vpc_id      = var.vpc_id

  # Rules live in separate aws_vpc_security_group_ingress_rule resources so that
  # rule changes never replace the SG (and thus never churn the endpoints).
  # No egress rules: interface endpoints terminate connections at the ENI, so
  # the endpoint SG needs no outbound rules.

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpce-sg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from ${each.value} (e.g. on-prem / VPC over VPN)."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpce-443"
    ManagedBy = "Terraform"
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_sg" {
  for_each = var.allowed_security_group_ids

  security_group_id = aws_security_group.endpoints.id
  # NOTE: SG rule descriptions reach the EC2 API, which rejects apostrophes
  # (allowed set: a-zA-Z0-9. _-:/()#,@[]+=&;{}!$*).
  description                  = "HTTPS from security group ${each.key}."
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpce-443-${each.key}"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Interface (PrivateLink) endpoints, one per requested service
################################################################################

resource "aws_vpc_endpoint" "this" {
  for_each = toset(var.service_names)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = var.private_dns_enabled

  # Least-privilege endpoint policy when supplied; null => default full access.
  policy = lookup(var.endpoint_policies, each.value, null)

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpce-${each.value}"
    ManagedBy = "Terraform"
  })
}
