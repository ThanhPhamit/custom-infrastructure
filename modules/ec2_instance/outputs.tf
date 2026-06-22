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
