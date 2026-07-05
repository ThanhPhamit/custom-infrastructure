locals {
  # One ip_address block per subnet. The optional fixed IP is matched
  # positionally to subnet_ids; when no fixed IP is supplied for a given
  # index the value is null and AWS auto-assigns an address from the subnet.
  resolver_ip_addresses = [
    for idx, subnet_id in var.subnet_ids : {
      subnet_id = subnet_id
      ip        = try(element(var.ip_addresses, idx), null)
    }
  ]
}

################################################################################
# Security group — DNS (53 udp+tcp) from on-prem only, DNS egress to the VPC
################################################################################

resource "aws_security_group" "resolver" {
  name_prefix = "${var.app_name}-resolver-inbound-"
  description = "Route 53 Resolver inbound endpoint - allow DNS (53) from on-prem, egress DNS to the VPC."
  vpc_id      = var.vpc_id

  # Rules live in separate aws_vpc_security_group_*_rule resources so that rule
  # changes never replace the SG. That matters doubly here: the resolver
  # endpoint's SG set is immutable, so an SG replacement would force an endpoint
  # replacement and hand out new ENI IPs (breaking the on-prem forwarders).

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-inbound-sg"
    ManagedBy = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  # One rule per (protocol, source CIDR) pair — DNS needs both UDP and TCP.
  resolver_ingress_rules = {
    for pair in setproduct(["udp", "tcp"], var.allowed_cidr_blocks) :
    "${pair[0]}-${pair[1]}" => { protocol = pair[0], cidr = pair[1] }
  }
}

resource "aws_vpc_security_group_ingress_rule" "resolver" {
  for_each = local.resolver_ingress_rules

  security_group_id = aws_security_group.resolver.id
  description       = "DNS over ${upper(each.value.protocol)} from ${each.value.cidr} (on-prem)."
  from_port         = 53
  to_port           = 53
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-dns-${each.value.protocol}"
    ManagedBy = "Terraform"
  })
}

resource "aws_vpc_security_group_egress_rule" "resolver" {
  for_each = toset(["udp", "tcp"])

  security_group_id = aws_security_group.resolver.id
  description       = "DNS over ${upper(each.value)} to the VPC (native resolver / private zones)."
  from_port         = 53
  to_port           = 53
  ip_protocol       = each.value
  cidr_ipv4         = var.vpc_cidr

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-egress-${each.value}"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Route 53 Resolver inbound endpoint — one ENI per subnet
################################################################################

resource "aws_route53_resolver_endpoint" "this" {
  name               = "${var.app_name}-resolver-inbound"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = local.resolver_ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = ip_address.value.ip
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-inbound"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Resolver query logging to CloudWatch Logs (optional)
#
# NOTE: Route 53 *Resolver* query logging delivers via the service-linked role
# AWSServiceRoleForRoute53Resolver (logs:CreateLogDelivery / "vended logs"), so NO
# aws_cloudwatch_log_resource_policy is required on this log group. The manual
# resource policy (principal route53.amazonaws.com, us-east-1) is only for Route 53
# *hosted-zone* query logging — a different service. (Verified vs AWS docs 2026-06-30.)
################################################################################

resource "aws_cloudwatch_log_group" "resolver" {
  count = var.enable_query_logging ? 1 : 0

  name              = "/aws/route53/resolver/${var.app_name}"
  retention_in_days = var.query_log_retention_days
  kms_key_id        = var.log_group_kms_key_arn

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-qlog"
    ManagedBy = "Terraform"
  })
}

resource "aws_route53_resolver_query_log_config" "this" {
  count = var.enable_query_logging ? 1 : 0

  name            = "${var.app_name}-resolver-qlog"
  destination_arn = aws_cloudwatch_log_group.resolver[0].arn

  tags = merge(var.tags, {
    Name      = "${var.app_name}-resolver-qlog"
    ManagedBy = "Terraform"
  })
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  count = var.enable_query_logging ? 1 : 0

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this[0].id
  resource_id                  = var.vpc_id
}
