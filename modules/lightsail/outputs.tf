# ===== Instance =====

output "instance_name" {
  description = "Name of the Lightsail instance"
  value       = aws_lightsail_instance.this.name
}

output "instance_arn" {
  description = "ARN of the Lightsail instance"
  value       = aws_lightsail_instance.this.arn
}

output "public_ip" {
  description = "Public IP of the Lightsail instance (changes on stop/start — use static_ip instead)"
  value       = aws_lightsail_instance.this.public_ip_address
}

output "private_ip" {
  description = "Private IP of the Lightsail instance"
  value       = aws_lightsail_instance.this.private_ip_address
}

# ===== Static IP =====

output "static_ip" {
  description = "Static IP attached to the instance (does not change)"
  value       = aws_lightsail_static_ip.this.ip_address
}

# ===== SSH Key Pair =====

output "key_pair_name" {
  description = "Name of the Lightsail key pair (if created)"
  value       = var.key_pair_name != null ? aws_lightsail_key_pair.this[0].name : null
}

# ===== IAM Credentials =====

output "iam_user_name" {
  description = "IAM user name for app access (if created)"
  value       = var.create_iam_user ? aws_iam_user.app[0].name : null
}

output "iam_credentials_secret_arn" {
  description = "Secrets Manager ARN containing IAM access key + secret (if created)"
  value       = var.create_iam_user ? aws_secretsmanager_secret.app_credentials[0].arn : null
}

output "iam_credentials_secret_name" {
  description = "Secrets Manager secret name containing IAM access key + secret (if created)"
  value       = var.create_iam_user ? aws_secretsmanager_secret.app_credentials[0].name : null
}

# ===== SSH Config =====

output "ssh_config" {
  description = "SSH config entry — add to ~/.ssh/config"
  value       = <<-EOT
# ${var.app_name} Lightsail Server
Host ${var.app_name}-server
    HostName ${aws_lightsail_static_ip.this.ip_address}
    User ubuntu
    IdentitiesOnly yes
    IdentityFile ~/.ssh/${var.key_pair_name != null ? var.key_pair_name : "id_rsa"}
EOT
}
