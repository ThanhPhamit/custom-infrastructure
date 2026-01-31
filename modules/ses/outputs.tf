output "smtp_host" {
  description = "SES SMTP host"
  value       = "email-smtp.${data.aws_region.current.region}.amazonaws.com"
}

output "smtp_port" {
  description = "SES SMTP port"
  value       = "587"
}

output "iam_username" {
  description = "IAM user name for SES"
  value       = length(aws_iam_user.ses_smtp_user) > 0 ? aws_iam_user.ses_smtp_user[0].name : null
}

output "smtp_username" {
  description = "SMTP username (IAM Access Key ID)"
  value       = length(aws_iam_access_key.ses_smtp_access_key) > 0 ? aws_iam_access_key.ses_smtp_access_key[0].id : null
}

output "smtp_password_secret_arn" {
  description = "ARN of the secret containing SMTP password"
  value       = length(aws_secretsmanager_secret.ses_smtp_password) > 0 ? aws_secretsmanager_secret.ses_smtp_password[0].arn : null
}

output "smtp_username_secret_arn" {
  description = "ARN of the secret containing SMTP username"
  value       = length(aws_secretsmanager_secret.ses_smtp_username) > 0 ? aws_secretsmanager_secret.ses_smtp_username[0].arn : null
}

output "domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = length(aws_ses_domain_identity.domain) > 0 ? aws_ses_domain_identity.domain[0].arn : null
}

output "domain_verification_token" {
  description = "Domain verification token"
  value       = length(aws_ses_domain_identity.domain) > 0 ? aws_ses_domain_identity.domain[0].verification_token : null
}

output "email_templates" {
  description = "Map of email template names to their details"
  value = {
    for template in aws_ses_template.email_templates : template.name => {
      name    = template.name
      subject = template.subject
      arn     = template.arn
    }
  }
}
