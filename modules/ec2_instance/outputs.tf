output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IP in the VPC (peer instances reach this over the subnet)."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP — the Elastic IP if create_eip, else the instance's auto-assigned public IP (may be empty)."
  value       = var.create_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "availability_zone" {
  description = "AZ the instance (and its data volume) landed in."
  value       = aws_instance.this.availability_zone
}

output "security_group_id" {
  description = "ID of the instance's security group (use as a source_security_group_id for peers)."
  value       = aws_security_group.this.id
}

output "data_volume_id" {
  description = "ID of the optional data volume (null when create_data_volume = false)."
  value       = var.create_data_volume ? aws_ebs_volume.data[0].id : null
}

output "instance_role_arn" {
  description = "ARN of the in-module instance role (null unless enable_ssm)."
  value       = var.enable_ssm ? aws_iam_role.ssm[0].arn : null
}

output "instance_role_name" {
  description = "Name of the in-module instance role (null unless enable_ssm)."
  value       = var.enable_ssm ? aws_iam_role.ssm[0].name : null
}

# =============================================================================
# How to connect — SSM (enable_ssm) and/or SSH (key_name + a public address).
# Each output is null when its access method isn't configured on this instance.
# =============================================================================
locals {
  # Public address for the SSH convenience outputs: the EIP when created, else the
  # instance's auto-assigned public IP (empty in a private subnet).
  ssh_host = var.create_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip

  # SSH is only reachable when the box has both a key pair and a public address.
  ssh_available = var.key_name != null && (var.create_eip || var.associate_public_ip_address)
}

output "ssm_start_session_command" {
  description = "Command to open a shell via SSM Session Manager (enable_ssm). Null otherwise. Add --region/--profile as needed."
  value       = var.enable_ssm ? "aws ssm start-session --target ${aws_instance.this.id}" : null
}

output "ssh_command" {
  description = "One-line SSH command. Null unless key_name is set AND the instance has a public address (create_eip or associate_public_ip_address). Assumes the private key is at ~/.ssh/<key_name>.pem; set ssh_user to match the AMI."
  value       = local.ssh_available ? "ssh -i ~/.ssh/${var.key_name}.pem ${var.ssh_user}@${local.ssh_host}" : null
}

output "ssh_config" {
  description = "SSH config entry for the instance (add to ~/.ssh/config). Same requirements as ssh_command; null otherwise."
  value = local.ssh_available ? join("\n", [
    "# ${var.app_name}",
    "Host ${var.app_name}",
    "    HostName ${local.ssh_host}",
    "    User ${var.ssh_user}",
    "    IdentitiesOnly yes",
    "    IdentityFile ~/.ssh/${var.key_name}.pem",
  ]) : null
}
