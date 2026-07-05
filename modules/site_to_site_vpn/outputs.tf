output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway attached to the VPC."
  value       = aws_vpn_gateway.this.id
}

output "customer_gateway_id" {
  description = "ID of the static Customer Gateway (null once retain_static = false)."
  value       = one(aws_customer_gateway.this[*].id)
}

output "bgp_customer_gateway_id" {
  description = "ID of the BGP Customer Gateway (null when enable_bgp = false)."
  value       = one(aws_customer_gateway.bgp[*].id)
}

output "amazon_side_asn" {
  description = "Amazon-side BGP ASN on the VGW (the on-prem FRR peers to this as remote-as)."
  value       = var.amazon_side_asn
}

output "customer_gateway_bgp_asn" {
  description = "Customer-side BGP ASN (the on-prem FRR uses this as its local router bgp ASN)."
  value       = var.customer_gateway_bgp_asn
}

################################################################################
# STATIC connection (present while retain_static = true; null after cutover)
################################################################################

output "vpn_connection_id" {
  description = "ID of the static Site-to-Site VPN connection (null once retain_static = false)."
  value       = one(aws_vpn_connection.this[*].id)
}

output "tunnel1_address" {
  description = "Public IP of the AWS endpoint for static tunnel 1 (null after cutover)."
  value       = one(aws_vpn_connection.this[*].tunnel1_address)
}

output "tunnel2_address" {
  description = "Public IP of the AWS endpoint for static tunnel 2 (null after cutover)."
  value       = one(aws_vpn_connection.this[*].tunnel2_address)
}

output "tunnel1_preshared_key" {
  description = "Pre-shared key for static tunnel 1 (null after cutover). Sensitive."
  value       = one(aws_vpn_connection.this[*].tunnel1_preshared_key)
  sensitive   = true
}

output "tunnel2_preshared_key" {
  description = "Pre-shared key for static tunnel 2 (null after cutover). Sensitive."
  value       = one(aws_vpn_connection.this[*].tunnel2_preshared_key)
  sensitive   = true
}

################################################################################
# BGP connection (present while enable_bgp = true). Outside addresses + PSKs
# for the IPsec layer; inside /30 addresses for the route-based interface + BGP.
################################################################################

output "bgp_vpn_connection_id" {
  description = "ID of the BGP (dynamic-routing) Site-to-Site VPN connection (null when enable_bgp = false)."
  value       = one(aws_vpn_connection.bgp[*].id)
}

output "bgp_tunnel1_address" {
  description = "Public IP of the AWS endpoint for BGP tunnel 1 (strongSwan right=)."
  value       = one(aws_vpn_connection.bgp[*].tunnel1_address)
}

output "bgp_tunnel2_address" {
  description = "Public IP of the AWS endpoint for BGP tunnel 2 (strongSwan right=)."
  value       = one(aws_vpn_connection.bgp[*].tunnel2_address)
}

output "bgp_tunnel1_preshared_key" {
  description = "Pre-shared key for BGP tunnel 1; goes only in the on-prem /etc/ipsec.d/aws.secrets. Sensitive."
  value       = one(aws_vpn_connection.bgp[*].tunnel1_preshared_key)
  sensitive   = true
}

output "bgp_tunnel2_preshared_key" {
  description = "Pre-shared key for BGP tunnel 2; goes only in the on-prem /etc/ipsec.d/aws.secrets. Sensitive."
  value       = one(aws_vpn_connection.bgp[*].tunnel2_preshared_key)
  sensitive   = true
}

output "bgp_tunnel1_vgw_inside_address" {
  description = "AWS (VGW) inside address of BGP tunnel 1 — the BGP neighbor the on-prem FRR peers with over ipsec1."
  value       = one(aws_vpn_connection.bgp[*].tunnel1_vgw_inside_address)
}

output "bgp_tunnel2_vgw_inside_address" {
  description = "AWS (VGW) inside address of BGP tunnel 2 — the BGP neighbor the on-prem FRR peers with over ipsec2."
  value       = one(aws_vpn_connection.bgp[*].tunnel2_vgw_inside_address)
}

output "bgp_tunnel1_cgw_inside_address" {
  description = "On-prem (CGW) inside address of BGP tunnel 1 — assign to the ipsec1 interface (/30)."
  value       = one(aws_vpn_connection.bgp[*].tunnel1_cgw_inside_address)
}

output "bgp_tunnel2_cgw_inside_address" {
  description = "On-prem (CGW) inside address of BGP tunnel 2 — assign to the ipsec2 interface (/30)."
  value       = one(aws_vpn_connection.bgp[*].tunnel2_cgw_inside_address)
}
