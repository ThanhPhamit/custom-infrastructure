output "certificate_id" {
  value = aws_acm_certificate.this.id
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.this.arn
}

output "certificate_arn_virginia" {
  description = "ARN of the ACM certificate in Virginia region"
  value       = aws_acm_certificate.virginia.arn
}

output "certificate_domain_name" {
  description = "The domain name of the certificate"
  value       = aws_acm_certificate.this.domain_name
}

# Output CA certificate for workstation installation
output "ca_certificate_pem" {
  description = "The CA certificate in PEM format for installation on workstations"
  value       = data.local_file.ca_certificate.content
  sensitive   = false
}

output "ca_certificate_path" {
  description = "Path to the CA certificate file for workstation installation"
  value       = "${path.module}/certificates/ca-certificate.crt"
}

output "server_certificate_pem" {
  description = "The server certificate in PEM format"
  value       = data.local_file.server_certificate.content
  sensitive   = false
}

output "installation_command" {
  description = "Command to install CA certificate on workstations"
  value       = "cd ${path.module} && ./install-ca.sh certificates/ca-certificate.crt"
}
