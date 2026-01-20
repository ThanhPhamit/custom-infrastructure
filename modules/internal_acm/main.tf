# Generate certificates using OpenSSL scripts
resource "null_resource" "create_certificates" {
  triggers = {
    domain               = var.domain
    organization         = var.organization_name
    ca_validity_days     = var.ca_validity_days
    server_validity_days = var.server_validity_days
    cert_output_path     = local.absolute_cert_path
  }

  provisioner "local-exec" {
    command     = "TF_VAR_domain='${var.domain}' TF_VAR_organization='${var.organization_name}' TF_VAR_ca_validity_days='${var.ca_validity_days}' TF_VAR_server_validity_days='${var.server_validity_days}' TF_VAR_cert_output_path='${local.absolute_cert_path}' ./create-certificates.sh"
    working_dir = path.module
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "rm -rf '${self.triggers.cert_output_path}'"
    working_dir = path.module
  }
}

# Read the generated certificates
locals {
  # Convert relative path to absolute path
  absolute_cert_path = startswith(var.cert_output_path, "/") ? var.cert_output_path : abspath("${path.root}/${var.cert_output_path}")
}

data "local_file" "server_private_key" {
  filename   = "${local.absolute_cert_path}/server-private-key.pem"
  depends_on = [null_resource.create_certificates]
}

data "local_file" "server_certificate" {
  filename   = "${local.absolute_cert_path}/server-certificate.pem"
  depends_on = [null_resource.create_certificates]
}

data "local_file" "ca_certificate" {
  filename   = "${local.absolute_cert_path}/ca-certificate.pem"
  depends_on = [null_resource.create_certificates]
}

# Create CRT format for easier workstation installation
resource "local_file" "ca_certificate_crt" {
  content    = data.local_file.ca_certificate.content
  filename   = "${local.absolute_cert_path}/ca-certificate.crt"
  depends_on = [null_resource.create_certificates]
}

# Import certificates to AWS ACM
resource "aws_acm_certificate" "this" {
  private_key       = data.local_file.server_private_key.content
  certificate_body  = data.local_file.server_certificate.content
  certificate_chain = data.local_file.ca_certificate.content

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      "Name"         = "${var.domain}-ca-signed"
      "Type"         = "Internal-CA"
      "Domain"       = var.domain
      "Organization" = var.organization_name
    }
  )

  depends_on = [null_resource.create_certificates]
}

resource "aws_acm_certificate" "virginia" {
  provider = aws.virginia

  private_key       = data.local_file.server_private_key.content
  certificate_body  = data.local_file.server_certificate.content
  certificate_chain = data.local_file.ca_certificate.content

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      "Name"         = "${var.domain}-ca-signed-virginia"
      "Type"         = "Internal-CA"
      "Domain"       = var.domain
      "Organization" = var.organization_name
    }
  )

  depends_on = [null_resource.create_certificates]
}
