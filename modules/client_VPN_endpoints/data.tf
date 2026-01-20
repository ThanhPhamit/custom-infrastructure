data "aws_caller_identity" "user" {}
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_cidrs = [for assoc in data.aws_vpc.selected.cidr_block_associations : assoc.cidr_block]
}

################################################################################
# Generate Client VPN Config File
################################################################################

data "aws_ec2_client_vpn_endpoint" "selected" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id

  depends_on = [
    aws_ec2_client_vpn_endpoint.vpn
  ]
}

resource "local_file" "vpn_config" {
  filename = "${path.root}/client.ovpn"
  content  = <<-EOT
client
dev tun
proto udp
remote ${aws_ec2_client_vpn_endpoint.vpn.dns_name} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
${tls_self_signed_cert.ca_cert.cert_pem}
</ca>


reneg-sec 0

verify-x509-name server.${var.vpn_domain} name

<key>
${tls_private_key.client_key.private_key_pem}
</key>

<cert>
${tls_locally_signed_cert.client_cert.cert_pem}
</cert>
EOT

  file_permission = "0600"

  depends_on = [
    aws_ec2_client_vpn_endpoint.vpn,
    tls_locally_signed_cert.client_cert,
    tls_private_key.client_key,
    tls_self_signed_cert.ca_cert
  ]
}

################################################################################
# Generate TCP Client VPN Config File
################################################################################

resource "local_file" "vpn_tcp_config" {
  filename = "${path.root}/client-tcp.ovpn"
  content  = <<-EOT
client
dev tun
proto tcp
remote ${aws_ec2_client_vpn_endpoint.vpn_tcp.dns_name} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
${tls_self_signed_cert.ca_cert.cert_pem}
</ca>


reneg-sec 0

verify-x509-name server.${var.vpn_domain} name

<key>
${tls_private_key.client_key.private_key_pem}
</key>

<cert>
${tls_locally_signed_cert.client_cert.cert_pem}
</cert>
EOT

  file_permission = "0600"

  depends_on = [
    aws_ec2_client_vpn_endpoint.vpn_tcp,
    tls_locally_signed_cert.client_cert,
    tls_private_key.client_key,
    tls_self_signed_cert.ca_cert
  ]
}
