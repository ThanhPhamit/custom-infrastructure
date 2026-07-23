output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = local.provider_arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = aws_iam_role.github.name
}

output "iam_policy_arn" {
  description = "ARN of the built-in IAM policy for GitHub Actions (null when attach_default_permissions_policy = false)."
  value       = try(aws_iam_policy.github_actions_policy[0].arn, null)
}
