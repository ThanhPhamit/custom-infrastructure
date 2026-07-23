output "key_arn" {
  description = "ARN of the CMK (pass to EBS/RDS/SSM as kms_key_id)."
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "Key ID of the CMK."
  value       = aws_kms_key.this.key_id
}

output "alias_name" {
  description = "Alias name (alias/<app_name>)."
  value       = aws_kms_alias.this.name
}

output "alias_arn" {
  description = "ARN of the key alias."
  value       = aws_kms_alias.this.arn
}
