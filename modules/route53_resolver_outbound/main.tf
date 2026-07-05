locals {
  # One ip_address block per subnet; optional fixed IPs matched positionally
  # (mirrors route53_resolver_inbound). Pinning matters here so the ON-PREM
  # firewall can allow-list stable source IPs for the forwarded queries.
  resolver_ip_addresses = [
    for idx, subnet_id in var.subnet_ids : {
      subnet_id = subnet_id
      ip        = try(element(var.ip_addresses, idx), null)
    }
  ]

  # One egress rule per (protocol, target DNS IP) pair.
  egress_rules = {
    for pair in setproduct(["udp", "tcp"], var.target_dns_ips) :
    "${pair[0]}-${pair[1]}" => { protocol = pair[0], ip = pair[1] }
  }
}

################################################################################
# Security group — egress-only DNS to the on-prem DNS server(s). No ingress:
# the outbound endpoint only ORIGINATES queries.
################################################################################

resource "aws_security_group" "resolver" {
  name_prefix = "${var.app_name}-resolver-outbound-"
  description = "Route 53 Resolver outbound endpoint - egress DNS (53) to on-prem DNS only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-outbound-sg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "resolver" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.resolver.id
  description       = "DNS over ${upper(each.value.protocol)} to on-prem DNS ${each.value.ip}."
  from_port         = var.target_dns_port
  to_port           = var.target_dns_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = "${each.value.ip}/32"

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-out-${each.value.protocol}"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Outbound endpoint — one ENI per subnet; queries the VPC resolver forwards
# leave the VPC from these ENIs.
################################################################################

resource "aws_route53_resolver_endpoint" "this" {
  name      = "${var.app_name}-resolver-outbound"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = local.resolver_ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = ip_address.value.ip
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-outbound"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Forwarding rule + VPC association: queries for forward_domain go to the
# on-prem DNS server(s) — the authoritative source, no copies held in AWS.
################################################################################

resource "aws_route53_resolver_rule" "forward" {
  name                 = "${var.app_name}-forward-${replace(var.forward_domain, ".", "-")}"
  domain_name          = var.forward_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.this.id

  dynamic "target_ip" {
    for_each = toset(var.target_dns_ips)
    content {
      ip   = target_ip.value
      port = var.target_dns_port
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-forward-${replace(var.forward_domain, ".", "-")}"
    ManagedBy = "Terraform"
  })
}

resource "aws_route53_resolver_rule_association" "this" {
  resolver_rule_id = aws_route53_resolver_rule.forward.id
  vpc_id           = var.vpc_id
}
