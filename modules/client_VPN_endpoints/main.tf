################################################################################
# CA Key and Certificate (Root CA)
################################################################################

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "VPN Root CA"
    organization = var.organization_name
    country      = "JP"
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment"
  ]
}

################################################################################
# VPN Server Key and Certificate
################################################################################

resource "tls_private_key" "vpn_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "vpn_csr" {
  private_key_pem = tls_private_key.vpn_key.private_key_pem

  subject {
    common_name  = "server.${var.vpn_domain}"
    organization = var.organization_name
    country      = "JP"
  }
}

resource "tls_locally_signed_cert" "vpn_cert" {
  cert_request_pem   = tls_cert_request.vpn_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]

  set_subject_key_id = true
}

################################################################################
# Client Key and Certificate
################################################################################

resource "tls_private_key" "client_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client_csr" {
  private_key_pem = tls_private_key.client_key.private_key_pem

  subject {
    common_name  = "client.${var.vpn_domain}"
    organization = var.organization_name
    country      = "JP"
  }
}


resource "tls_locally_signed_cert" "client_cert" {
  cert_request_pem   = tls_cert_request.client_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = var.certificate_validity_period_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]

  set_subject_key_id = true
}


################################################################################
# Import Certificates to ACM
################################################################################

resource "aws_acm_certificate" "vpn_cert" {
  private_key       = tls_private_key.vpn_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.vpn_cert.cert_pem
  certificate_chain = tls_self_signed_cert.ca_cert.cert_pem

  tags = merge(var.tags, {
    Name = "vpn-server-${var.vpn_domain}"
  })
}

resource "aws_acm_certificate" "ca_cert" {
  private_key      = tls_private_key.ca_key.private_key_pem
  certificate_body = tls_self_signed_cert.ca_cert.cert_pem

  tags = merge(var.tags, {
    Name = "vpn-ca-${var.vpn_domain}"
  })
}


################################################################################
# Create Client VPN Endpoint #
################################################################################

resource "aws_security_group" "vpn" {
  name_prefix = "${var.app_name}-client-vpn-endpoint-sg"
  description = "Security group for Client VPN endpoint"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-client-vpn-endpoint-sg"
  })
}

# How AWS Client VPN Configuration Works:
# - Network Associations - Connect your VPN endpoint to subnets in your VPC
# - Authorization Rules - Control which network destinations clients can access
# - Routes - Define how traffic gets directed

resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description            = "Client VPN Endpoint for ${var.app_name}"
  server_certificate_arn = aws_acm_certificate.vpn_cert.arn
  client_cidr_block      = var.client_cidr_block
  vpc_id                 = var.vpc_id
  split_tunnel           = var.split_tunnel

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.ca_cert.arn
  }

  transport_protocol = "udp"
  security_group_ids = [aws_security_group.vpn.id]

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn_logs.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn_logs.name
  }

  dns_servers = ["169.254.169.253"]

  session_timeout_hours = 8

  client_login_banner_options {
    enabled     = true
    banner_text = "This VPN is for authorized users only. All activities may be monitored and recorded."
  }

  tags = merge(var.tags, {
    Name = "client-vpn-${var.vpn_domain}"
  })
}


################################################################################
# Client VPN Network Associations
################################################################################

# Associate Client VPN endpoint with specified subnets
# This creates Elastic Network Interfaces (ENIs) in each subnet for VPN connectivity
# IMPORTANT: Subnets must be either:
#   - Public subnets (with Internet Gateway route for 0.0.0.0/0)
#   - Private subnets with NAT Gateway (for internet access)
# Do NOT use private subnets without NAT Gateway - internet routes will fail
resource "aws_ec2_client_vpn_network_association" "vpn_subnet" {
  for_each               = var.enable_vpn_associations ? toset(var.subnet_ids) : []
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = each.value
}

# # Create authorization rules for all VPC CIDRs
# resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
#   for_each               = toset(local.vpc_cidrs)
#   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
#   target_network_cidr    = each.value
#   authorize_all_groups   = true
#   description            = "Allow access to VPC CIDR ${each.value}"
# }

################################################################################
# Client VPN Authorization Rules
################################################################################

# Authorization rules control which network destinations VPN clients can access
# These rules work in conjunction with routes to provide network access

# Allow VPN clients to access specific private subnet CIDRs
# This enables access to resources in private subnets (EC2, RDS, etc.)
resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  for_each               = var.enable_vpn_associations ? toset(var.private_subnet_cidrs) : []
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = "Allow access to private subnet ${each.value}"
}

# Allow VPN clients to reach ONLY the explicitly listed non-VPC destinations
# (e.g. the on-prem DB and the VPC DNS resolver). There is intentionally NO
# 0.0.0.0/0 rule: with split-tunnel this keeps dev internet on the local link
# and makes any unlisted on-prem range (e.g. customer production) unreachable.
resource "aws_ec2_client_vpn_authorization_rule" "split_tunnel_access" {
  for_each               = var.enable_vpn_associations ? toset(var.split_tunnel_destination_cidrs) : toset([])
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = "Allow access to ${each.value}"
}


################################################################################
# Client VPN Routes
################################################################################

# Routes define HOW traffic gets directed from VPN clients to destinations
# Each route specifies a destination CIDR and which subnet to route through

# One route per (destination CIDR x associated subnet). VPC CIDRs are already
# routed automatically by the subnet association, so only the extra
# split-tunnel destinations need explicit routes here.
resource "aws_ec2_client_vpn_route" "split_tunnel_route" {
  for_each = var.enable_vpn_associations ? {
    for pair in setproduct(var.split_tunnel_destination_cidrs, var.subnet_ids) :
    "${pair[0]}_${pair[1]}" => { cidr = pair[0], subnet = pair[1] }
  } : {}
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  destination_cidr_block = each.value.cidr
  target_vpc_subnet_id   = each.value.subnet
  description            = "Route to ${each.value.cidr} via subnet ${each.value.subnet}"

  depends_on = [aws_ec2_client_vpn_network_association.vpn_subnet]
}


################################################################################
# Logging
################################################################################

resource "aws_cloudwatch_log_group" "vpn_logs" {
  # encrypted by default
  name              = "/aws/vpn/${var.vpn_domain}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "vpn-logs-${var.vpn_domain}"
  })
}

resource "aws_cloudwatch_log_stream" "vpn_logs" {
  name           = "${var.app_name}-client-vpn-endpoint-logs"
  log_group_name = aws_cloudwatch_log_group.vpn_logs.name
}
