output "policy_id" {
  description = "ID of the DLM lifecycle policy."
  value       = aws_dlm_lifecycle_policy.this.id
}

output "policy_arn" {
  description = "ARN of the DLM lifecycle policy."
  value       = aws_dlm_lifecycle_policy.this.arn
}

output "execution_role_arn" {
  description = "ARN of the DLM execution role."
  value       = aws_iam_role.dlm.arn
}
