################################################################################
# General
################################################################################

variable "app_name" {
  description = "Application/name prefix applied to every resource name and the Name tag (e.g. \"s2s-vpn-lab\")."
  type        = string

  validation {
    condition     = length(trimspace(var.app_name)) > 0
    error_message = "app_name must be a non-empty string."
  }
}

variable "tags" {
  description = "Additional tags merged onto every taggable resource created by this module."
  type        = map(string)
  default     = {}
}

################################################################################
# Routing-mode migration toggles (static → BGP, validate-first)
################################################################################

variable "enable_bgp" {
  description = "Create a second, BGP (dynamic-routing) VPN connection on the same VGW/CGW. Used to validate route-based/BGP in parallel with the live static connection before cutting over."
  type        = bool
  default     = false
}

variable "retain_static" {
  description = "Keep the original static-routing VPN connection and its static route. Set to false at cutover to destroy the static connection; the BGP connection then owns routing. NOTE: AWS dedupes customer gateways by (ip, asn) and forbids a static + BGP connection on the same CGW↔VGW pair. If the BGP peer IP equals customer_gateway_ip they share one CGW, so static and BGP cannot coexist — cutover is a two-apply sequence (destroy static: retain_static=false, enable_bgp=false; THEN create BGP: enable_bgp=true) with a brief no-connection window. Giving BGP a DISTINCT bgp_customer_gateway_ip (a new provider) puts it on its own CGW so both run in parallel for validate-first cutover with no outage."
  type        = bool
  default     = true
}

################################################################################
# Virtual Private Gateway / Customer Gateway
################################################################################

variable "vpc_id" {
  description = "ID of the VPC the Virtual Private Gateway is attached to. Setting vpc_id on the VGW performs the attachment."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g. vpc-0123456789abcdef0)."
  }
}

variable "bgp_customer_gateway_ip" {
  description = "Public IPv4 of the on-prem peer for the BGP connection, when it differs from customer_gateway_ip (e.g. a new provider being validated in parallel). Defaults to customer_gateway_ip when null."
  type        = string
  default     = null
}

variable "customer_gateway_ip" {
  description = "Public IPv4 address of the on-prem customer gateway device (the IPsec peer endpoint)."
  type        = string

  validation {
    condition     = can(cidrhost("${var.customer_gateway_ip}/32", 0))
    error_message = "customer_gateway_ip must be a valid IPv4 address."
  }
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN of the customer gateway. Required by AWS even for static-routing VPNs; informational only when static_routes_only = true."
  type        = number
  default     = 65000

  validation {
    condition     = var.customer_gateway_bgp_asn >= 1 && var.customer_gateway_bgp_asn <= 4294967295
    error_message = "customer_gateway_bgp_asn must be in the range 1-4294967295."
  }
}

variable "amazon_side_asn" {
  description = "Amazon-side BGP ASN assigned to the Virtual Private Gateway."
  type        = number
  default     = 64512

  validation {
    condition     = var.amazon_side_asn >= 1 && var.amazon_side_asn <= 4294967295
    error_message = "amazon_side_asn must be in the range 1-4294967295."
  }
}

################################################################################
# Routing
################################################################################

variable "onprem_cidr" {
  description = "On-prem network CIDR reachable over the tunnel; added as the static route on the VPN connection (e.g. 10.100.0.0/24)."
  type        = string

  validation {
    condition     = can(cidrhost(var.onprem_cidr, 0))
    error_message = "onprem_cidr must be a valid IPv4 CIDR block (e.g. 10.100.0.0/24)."
  }
}

variable "route_table_ids" {
  description = "Route table IDs on which to enable VGW route propagation so the on-prem static route is installed automatically."
  type        = list(string)
  default     = []
}

################################################################################
# Pinned IPsec proposals (mirrored on the on-prem device)
################################################################################

variable "tunnel_ike_versions" {
  description = "Permitted IKE versions for both tunnels (e.g. [\"ikev2\"])."
  type        = list(string)
  default     = ["ikev2"]

  validation {
    condition     = length(var.tunnel_ike_versions) > 0 && alltrue([for v in var.tunnel_ike_versions : contains(["ikev1", "ikev2"], v)])
    error_message = "tunnel_ike_versions must be a non-empty subset of [\"ikev1\", \"ikev2\"]."
  }
}

variable "tunnel_phase1_encryption_algorithms" {
  description = "Permitted Phase 1 (IKE) encryption algorithms for both tunnels (e.g. [\"AES256\"])."
  type        = list(string)
  default     = ["AES256"]

  validation {
    condition     = length(var.tunnel_phase1_encryption_algorithms) > 0
    error_message = "tunnel_phase1_encryption_algorithms must contain at least one algorithm."
  }
}

variable "tunnel_phase2_encryption_algorithms" {
  description = "Permitted Phase 2 (IPsec) encryption algorithms for both tunnels (e.g. [\"AES256\"])."
  type        = list(string)
  default     = ["AES256"]

  validation {
    condition     = length(var.tunnel_phase2_encryption_algorithms) > 0
    error_message = "tunnel_phase2_encryption_algorithms must contain at least one algorithm."
  }
}

variable "tunnel_phase1_integrity_algorithms" {
  description = "Permitted Phase 1 (IKE) integrity algorithms for both tunnels (e.g. [\"SHA2-256\"])."
  type        = list(string)
  default     = ["SHA2-256"]

  validation {
    condition     = length(var.tunnel_phase1_integrity_algorithms) > 0
    error_message = "tunnel_phase1_integrity_algorithms must contain at least one algorithm."
  }
}

variable "tunnel_phase2_integrity_algorithms" {
  description = "Permitted Phase 2 (IPsec) integrity algorithms for both tunnels (e.g. [\"SHA2-256\"])."
  type        = list(string)
  default     = ["SHA2-256"]

  validation {
    condition     = length(var.tunnel_phase2_integrity_algorithms) > 0
    error_message = "tunnel_phase2_integrity_algorithms must contain at least one algorithm."
  }
}

variable "tunnel_phase1_dh_group_numbers" {
  description = "Permitted Phase 1 (IKE) Diffie-Hellman group numbers for both tunnels (e.g. [20])."
  type        = list(number)
  default     = [20]

  validation {
    condition     = length(var.tunnel_phase1_dh_group_numbers) > 0
    error_message = "tunnel_phase1_dh_group_numbers must contain at least one DH group number."
  }
}

variable "tunnel_phase2_dh_group_numbers" {
  description = "Permitted Phase 2 (IPsec) Diffie-Hellman group numbers for both tunnels (e.g. [20])."
  type        = list(number)
  default     = [20]

  validation {
    condition     = length(var.tunnel_phase2_dh_group_numbers) > 0
    error_message = "tunnel_phase2_dh_group_numbers must contain at least one DH group number."
  }
}

variable "tunnel_dpd_timeout_action" {
  description = "Action taken on Dead Peer Detection (DPD) timeout for both tunnels: clear, none, or restart."
  type        = string
  default     = "restart"

  validation {
    condition     = contains(["clear", "none", "restart"], var.tunnel_dpd_timeout_action)
    error_message = "tunnel_dpd_timeout_action must be one of: clear, none, restart."
  }
}

variable "tunnel_startup_action" {
  description = "Startup action for both tunnels: \"add\" (wait for the peer to initiate) or \"start\" (initiate). AWS default is \"add\"."
  type        = string
  default     = "add"

  validation {
    condition     = contains(["add", "start"], var.tunnel_startup_action)
    error_message = "tunnel_startup_action must be \"add\" or \"start\"."
  }
}

variable "tunnel_phase1_lifetime_seconds" {
  description = "Phase 1 (IKE SA) lifetime in seconds for both tunnels (900-28800). Mirror on the on-prem device (strongSwan ikelifetime)."
  type        = number
  default     = 28800

  validation {
    condition     = var.tunnel_phase1_lifetime_seconds >= 900 && var.tunnel_phase1_lifetime_seconds <= 28800
    error_message = "tunnel_phase1_lifetime_seconds must be between 900 and 28800."
  }
}

variable "tunnel_phase2_lifetime_seconds" {
  description = "Phase 2 (IPsec SA) lifetime in seconds for both tunnels (900-3600). Mirror on the on-prem device (strongSwan salifetime)."
  type        = number
  default     = 3600

  validation {
    condition     = var.tunnel_phase2_lifetime_seconds >= 900 && var.tunnel_phase2_lifetime_seconds <= 3600
    error_message = "tunnel_phase2_lifetime_seconds must be between 900 and 3600."
  }
}

variable "tunnel_rekey_margin_time_seconds" {
  description = "Margin time (seconds) before Phase 2 SA expiry at which rekey begins, for both tunnels (60 to half the Phase 2 lifetime)."
  type        = number
  default     = 540
}

variable "tunnel_rekey_fuzz_percentage" {
  description = "Percentage by which the rekey time is randomized around the margin, for both tunnels (0-100)."
  type        = number
  default     = 100

  validation {
    condition     = var.tunnel_rekey_fuzz_percentage >= 0 && var.tunnel_rekey_fuzz_percentage <= 100
    error_message = "tunnel_rekey_fuzz_percentage must be between 0 and 100."
  }
}

variable "tunnel_replay_window_size" {
  description = "IKE replay window size (packets) for both tunnels (64-2048)."
  type        = number
  default     = 1024

  validation {
    condition     = var.tunnel_replay_window_size >= 64 && var.tunnel_replay_window_size <= 2048
    error_message = "tunnel_replay_window_size must be between 64 and 2048."
  }
}

################################################################################
# CloudWatch TunnelState alarms (optional)
################################################################################

variable "enable_tunnel_state_alarms" {
  description = "Whether to create CloudWatch alarms that fire when either tunnel's TunnelState drops below UP (1)."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified on ALARM and OK transitions for the TunnelState alarms (only used when enable_tunnel_state_alarms = true)."
  type        = list(string)
  default     = []
}
