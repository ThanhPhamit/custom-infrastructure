locals {
  # Alarm targets are built from whichever connection(s) exist. During the
  # static→BGP migration both may be live (retain_static + enable_bgp); after
  # cutover only the BGP connection remains. Keys drive alarm naming; each value
  # carries the tunnel outside address + the owning VpnId dimension.
  _static_alarm_targets = (var.enable_tunnel_state_alarms && var.retain_static) ? {
    "tunnel1" = { addr = aws_vpn_connection.this[0].tunnel1_address, vpn = aws_vpn_connection.this[0].id }
    "tunnel2" = { addr = aws_vpn_connection.this[0].tunnel2_address, vpn = aws_vpn_connection.this[0].id }
  } : {}

  _bgp_alarm_targets = (var.enable_tunnel_state_alarms && var.enable_bgp) ? {
    "bgp-tunnel1" = { addr = aws_vpn_connection.bgp[0].tunnel1_address, vpn = aws_vpn_connection.bgp[0].id }
    "bgp-tunnel2" = { addr = aws_vpn_connection.bgp[0].tunnel2_address, vpn = aws_vpn_connection.bgp[0].id }
  } : {}

  tunnel_alarm_targets = merge(local._static_alarm_targets, local._bgp_alarm_targets)
}

################################################################################
# Virtual Private Gateway (attached to the VPC via vpc_id)
################################################################################

resource "aws_vpn_gateway" "this" {
  vpc_id          = var.vpc_id
  amazon_side_asn = var.amazon_side_asn

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpn-gateway"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Customer Gateway (the on-prem IPsec peer). Shared by the static and BGP
# connections; bgp_asn becomes live once a BGP connection exists.
################################################################################

moved {
  from = aws_customer_gateway.this
  to   = aws_customer_gateway.this[0]
}

resource "aws_customer_gateway" "this" {
  count = var.retain_static ? 1 : 0

  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = merge(var.tags, {
    Name      = "${var.app_name}-customer-gateway"
    ManagedBy = "Terraform"
  })
}

# Separate CGW for the BGP connection. AWS refuses two connections with different
# static_routes_only values on the SAME CGW↔VGW pair (InvalidOption.Conflict), so BGP
# needs its own CGW. But AWS also DEDUPES customer gateways by (ip_address, bgp_asn): if
# bgp_customer_gateway_ip resolves to the same IP as customer_gateway_ip, this "second"
# CGW collapses onto the static one → the pair collides again → static and BGP CANNOT both
# be live. They coexist only for a validate-first window with a DISTINCT peer IP (e.g. a new
# provider). Only exists while enable_bgp = true.
resource "aws_customer_gateway" "bgp" {
  count = var.enable_bgp ? 1 : 0

  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = coalesce(var.bgp_customer_gateway_ip, var.customer_gateway_ip)
  type       = "ipsec.1"

  tags = merge(var.tags, {
    Name      = "${var.app_name}-customer-gateway-bgp"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Site-to-Site VPN connection — STATIC routing (original). Gated by
# retain_static so it can be destroyed at cutover once BGP is validated.
# `moved` preserves the pre-count state address (no destroy/recreate).
################################################################################

moved {
  from = aws_vpn_connection.this
  to   = aws_vpn_connection.this[0]
}

resource "aws_vpn_connection" "this" {
  count = var.retain_static ? 1 : 0

  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.this[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  # ---- Tunnel 1 (pinned IPsec proposals + DPD) ----
  tunnel1_ike_versions                 = var.tunnel_ike_versions
  tunnel1_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel1_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel1_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms
  tunnel1_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms
  tunnel1_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel1_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel1_dpd_timeout_action           = var.tunnel_dpd_timeout_action
  tunnel1_startup_action               = var.tunnel_startup_action
  tunnel1_phase1_lifetime_seconds      = var.tunnel_phase1_lifetime_seconds
  tunnel1_phase2_lifetime_seconds      = var.tunnel_phase2_lifetime_seconds
  tunnel1_rekey_margin_time_seconds    = var.tunnel_rekey_margin_time_seconds
  tunnel1_rekey_fuzz_percentage        = var.tunnel_rekey_fuzz_percentage
  tunnel1_replay_window_size           = var.tunnel_replay_window_size

  # ---- Tunnel 2 (pinned IPsec proposals + DPD) ----
  tunnel2_ike_versions                 = var.tunnel_ike_versions
  tunnel2_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel2_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel2_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms
  tunnel2_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms
  tunnel2_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel2_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel2_dpd_timeout_action           = var.tunnel_dpd_timeout_action
  tunnel2_startup_action               = var.tunnel_startup_action
  tunnel2_phase1_lifetime_seconds      = var.tunnel_phase1_lifetime_seconds
  tunnel2_phase2_lifetime_seconds      = var.tunnel_phase2_lifetime_seconds
  tunnel2_rekey_margin_time_seconds    = var.tunnel_rekey_margin_time_seconds
  tunnel2_rekey_fuzz_percentage        = var.tunnel_rekey_fuzz_percentage
  tunnel2_replay_window_size           = var.tunnel_replay_window_size

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpn-connection"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Site-to-Site VPN connection — BGP (dynamic routing, route-based on-prem).
# Same VGW + identical hardened tunnel proposals; only the routing mode differs.
# Runs alongside the static connection for validate-first cutover ONLY when it sits on a
# distinct-IP CGW (see aws_customer_gateway.bgp); with the same peer IP the two collide on
# one VGW and cutover must be the two-apply sequence documented on var.retain_static.
################################################################################

resource "aws_vpn_connection" "bgp" {
  count = var.enable_bgp ? 1 : 0

  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.bgp[0].id
  type                = "ipsec.1"
  static_routes_only  = false

  # ---- Tunnel 1 (pinned IPsec proposals + DPD) ----
  tunnel1_ike_versions                 = var.tunnel_ike_versions
  tunnel1_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel1_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel1_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms
  tunnel1_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms
  tunnel1_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel1_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel1_dpd_timeout_action           = var.tunnel_dpd_timeout_action
  tunnel1_startup_action               = var.tunnel_startup_action
  tunnel1_phase1_lifetime_seconds      = var.tunnel_phase1_lifetime_seconds
  tunnel1_phase2_lifetime_seconds      = var.tunnel_phase2_lifetime_seconds
  tunnel1_rekey_margin_time_seconds    = var.tunnel_rekey_margin_time_seconds
  tunnel1_rekey_fuzz_percentage        = var.tunnel_rekey_fuzz_percentage
  tunnel1_replay_window_size           = var.tunnel_replay_window_size

  # ---- Tunnel 2 (pinned IPsec proposals + DPD) ----
  tunnel2_ike_versions                 = var.tunnel_ike_versions
  tunnel2_phase1_encryption_algorithms = var.tunnel_phase1_encryption_algorithms
  tunnel2_phase2_encryption_algorithms = var.tunnel_phase2_encryption_algorithms
  tunnel2_phase1_integrity_algorithms  = var.tunnel_phase1_integrity_algorithms
  tunnel2_phase2_integrity_algorithms  = var.tunnel_phase2_integrity_algorithms
  tunnel2_phase1_dh_group_numbers      = var.tunnel_phase1_dh_group_numbers
  tunnel2_phase2_dh_group_numbers      = var.tunnel_phase2_dh_group_numbers
  tunnel2_dpd_timeout_action           = var.tunnel_dpd_timeout_action
  tunnel2_startup_action               = var.tunnel_startup_action
  tunnel2_phase1_lifetime_seconds      = var.tunnel_phase1_lifetime_seconds
  tunnel2_phase2_lifetime_seconds      = var.tunnel_phase2_lifetime_seconds
  tunnel2_rekey_margin_time_seconds    = var.tunnel_rekey_margin_time_seconds
  tunnel2_rekey_fuzz_percentage        = var.tunnel_rekey_fuzz_percentage
  tunnel2_replay_window_size           = var.tunnel_replay_window_size

  tags = merge(var.tags, {
    Name      = "${var.app_name}-vpn-connection-bgp"
    ManagedBy = "Terraform"
  })
}

################################################################################
# Static route to the on-prem network (STATIC connection only). Not valid on a
# BGP connection — gated with the static connection.
################################################################################

moved {
  from = aws_vpn_connection_route.onprem
  to   = aws_vpn_connection_route.onprem[0]
}

resource "aws_vpn_connection_route" "onprem" {
  count = var.retain_static ? 1 : 0

  destination_cidr_block = var.onprem_cidr
  vpn_connection_id      = aws_vpn_connection.this[0].id
}

################################################################################
# VGW route propagation onto caller-supplied route tables. VGW-level, so it
# carries the static route today and the BGP-learned route after cutover.
################################################################################

# NOTE: count (not for_each) — route table IDs come from another module and are not
# known until apply; for_each keys must be known at plan time, count length need not be.
resource "aws_vpn_gateway_route_propagation" "this" {
  count = length(var.route_table_ids)

  route_table_id = var.route_table_ids[count.index]
  vpn_gateway_id = aws_vpn_gateway.this.id
}

################################################################################
# CloudWatch TunnelState alarms (optional, one per live tunnel across both
# connections)
################################################################################

resource "aws_cloudwatch_metric_alarm" "tunnel_state" {
  for_each = local.tunnel_alarm_targets

  alarm_name          = "${var.app_name}-${each.key}-state"
  alarm_description   = "Site-to-Site VPN ${each.key} (${each.value.addr}) is DOWN: TunnelState dropped below UP (1)."
  namespace           = "AWS/VPN"
  metric_name         = "TunnelState"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = 1

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  dimensions = {
    VpnId           = each.value.vpn
    TunnelIpAddress = each.value.addr
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-${each.key}-state"
    ManagedBy = "Terraform"
  })
}
