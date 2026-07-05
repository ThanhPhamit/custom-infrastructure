output "bootstrap_user_name" {
  description = "Name of the bootstrap IAM user (the on-prem host's only long-lived identity)."
  value       = aws_iam_user.bootstrap.name
}

output "bootstrap_user_arn" {
  description = "ARN of the bootstrap IAM user."
  value       = aws_iam_user.bootstrap.arn
}

output "access_role_arn" {
  description = "ARN of the access role to pass to sts:AssumeRole (RoleArn)."
  value       = aws_iam_role.access.arn
}

output "access_role_name" {
  description = "Name of the access role."
  value       = aws_iam_role.access.name
}

output "bootstrap_access_key_id" {
  description = "Access key ID for the bootstrap user, or null when create_access_key is false."
  value       = try(aws_iam_access_key.bootstrap[0].id, null)
  sensitive   = true
}

output "bootstrap_secret_access_key" {
  description = "Secret access key for the bootstrap user, or null when create_access_key is false. Lands in Terraform state (see README SECURITY NOTE)."
  value       = try(aws_iam_access_key.bootstrap[0].secret, null)
  sensitive   = true
}
