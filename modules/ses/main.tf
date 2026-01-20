# SES Domain Identity
resource "aws_ses_domain_identity" "domain" {
  count  = var.domain_name != null ? 1 : 0
  domain = var.domain_name
}

# SES Domain DKIM
# resource "aws_ses_domain_dkim" "domain_dkim" {
#   count  = var.domain_name != null ? 1 : 0
#   domain = var.domain_name
# }

# # Route53 records for SES verification
# resource "aws_route53_record" "ses_verification" {
#   count   = var.domain_name != null ? 1 : 0
#   zone_id = var.route_53_zone_id
#   name    = "_amazonses.${var.domain_name}"
#   type    = "TXT"
#   ttl     = "600"
#   records = [aws_ses_domain_identity.domain[0].verification_token]
# }

# # Route53 records for DKIM
# resource "aws_route53_record" "ses_dkim" {
#   count   = var.domain_name != null ? 3 : 0
#   zone_id = var.route_53_zone_id
#   name    = var.domain_name != null ? "${aws_ses_domain_dkim.domain_dkim[0].dkim_tokens[count.index]}._domainkey.${var.domain_name}" : null
#   type    = "CNAME"
#   ttl     = "600"
#   records = var.domain_name != null ? ["${aws_ses_domain_dkim.domain_dkim[0].dkim_tokens[count.index]}.dkim.amazonses.com"] : []
# }

# SES Email Identities
resource "aws_ses_email_identity" "email_identities" {
  count = length(var.email_identities)
  email = var.email_identities[count.index]
}

# IAM User for SMTP
resource "aws_iam_user" "ses_smtp_user" {
  count = var.create_smtp_user ? 1 : 0
  name  = "${var.app_name}-ses-smtp-user"
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ses-smtp-user"
    }
  )
}

# IAM Policy for SES
resource "aws_iam_policy" "ses_smtp_policy" {
  count       = var.create_smtp_user ? 1 : 0
  name        = "${var.app_name}-ses-smtp-policy"
  description = "Policy for SES SMTP access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ses-smtp-policy"
    }
  )
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "ses_smtp_user_policy" {
  count      = var.create_smtp_user ? 1 : 0
  user       = aws_iam_user.ses_smtp_user[0].name
  policy_arn = aws_iam_policy.ses_smtp_policy[0].arn
}

# Access Key for SMTP
resource "aws_iam_access_key" "ses_smtp_access_key" {
  count = var.create_smtp_user ? 1 : 0
  user  = aws_iam_user.ses_smtp_user[0].name
}

resource "random_uuid" "ses_smtp_password_uuid" {
  count = var.create_smtp_user ? 1 : 0
}

# Store SMTP password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "ses_smtp_password" {
  count       = var.create_smtp_user ? 1 : 0
  name        = "${var.app_name}-ses-smtp-password-${substr(random_uuid.ses_smtp_password_uuid[0].result, 0, 2)}"
  description = "SES SMTP password for ${var.app_name}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ses-smtp-password-${substr(random_uuid.ses_smtp_password_uuid[0].result, 0, 2)}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "ses_smtp_password" {
  count         = var.create_smtp_user ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ses_smtp_password[0].id
  secret_string = aws_iam_access_key.ses_smtp_access_key[0].ses_smtp_password_v4
}

# SES Email Templates
resource "aws_ses_template" "email_templates" {
  count   = length(var.email_templates)
  name    = var.email_templates[count.index].name
  subject = var.email_templates[count.index].subject
  html    = var.email_templates[count.index].html
  text    = var.email_templates[count.index].text
}
