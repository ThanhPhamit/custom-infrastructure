# AWS SES Email Service Terraform Module

Terraform module which creates SES resources for email sending.

## Features

This module supports creating:

- **Domain Identity** - Email domain verification
- **Email Identities** - Individual email verification
- **Email Templates** - Reusable email templates
- **SMTP Credentials** - IAM user for SMTP sending
- **Secrets Manager** - Secure SMTP password storage

## Usage

### Example 1: Basic SES with Templates

```terraform
module "ses" {
  source = "../../modules/ses"

  app_name         = "${var.environment}-${var.app_name}"
  email_identities = []
  create_smtp_user = false

  email_templates = [
    {
      name    = "contact-template"
      subject = "New Contact Form Submission"
      html    = file("${path.module}/templates/contact.html")
      text    = file("${path.module}/templates/contact.txt")
    },
    {
      name    = "welcome-template"
      subject = "Welcome to Our Service"
      html    = file("${path.module}/templates/welcome.html")
      text    = file("${path.module}/templates/welcome.txt")
    }
  ]

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: SES with Domain and SMTP User

```terraform
module "ses" {
  source = "../../modules/ses"

  app_name    = "${var.environment}-${var.app_name}"
  domain_name = "example.com"

  email_identities = [
    "noreply@example.com",
    "support@example.com"
  ]

  create_smtp_user = true

  email_templates = var.email_templates

  tags = local.tags
}
```

### Example 3: Email Template Definition

```terraform
variable "email_templates" {
  default = [
    {
      name    = "contact-notification"
      subject = "New Contact: {{contact_name}}"
      html    = <<EOF
<p>New contact received:</p>
<ul>
  <li>Name: {{contact_name}}</li>
  <li>Email: {{email}}</li>
  <li>Message: {{message}}</li>
</ul>
EOF
      text    = <<EOF
New contact received:
Name: {{contact_name}}
Email: {{email}}
Message: {{message}}
EOF
    }
  ]
}
```

## Email Template Variables

Templates support Handlebars-style variables:

```html
<p>Hello, {{name}}!</p>
<p>Your order #{{order_id}} has been shipped.</p>
```

## Sending Emails with Templates (Node.js)

```javascript
const { SESClient, SendTemplatedEmailCommand } = require('@aws-sdk/client-ses');

const sesClient = new SESClient({ region: 'ap-northeast-1' });

const command = new SendTemplatedEmailCommand({
  Source: 'noreply@example.com',
  Destination: {
    ToAddresses: ['recipient@example.com'],
  },
  Template: 'contact-notification',
  TemplateData: JSON.stringify({
    contact_name: 'John Doe',
    email: 'john@example.com',
    message: 'Hello from the contact form!',
  }),
});

await sesClient.send(command);
```

## SMTP Configuration

When `create_smtp_user = true`, the module creates SMTP credentials:

| Setting   | Value                               |
| --------- | ----------------------------------- |
| SMTP Host | `email-smtp.<region>.amazonaws.com` |
| SMTP Port | 587 (TLS) or 465 (SSL)              |
| Username  | IAM Access Key ID                   |
| Password  | Stored in Secrets Manager           |

## Inputs

| Name             | Description                          | Type           | Default | Required |
| ---------------- | ------------------------------------ | -------------- | ------- | :------: |
| app_name         | Application name for resource naming | `string`       | n/a     |   yes    |
| domain_name      | Domain name for SES domain identity  | `string`       | `null`  |    no    |
| email_identities | List of email addresses to verify    | `list(string)` | `[]`    |    no    |
| create_smtp_user | Create IAM user for SMTP             | `bool`         | `false` |    no    |
| email_templates  | List of email templates to create    | `list(object)` | `[]`    |    no    |
| tags             | Tags to apply to resources           | `map(string)`  | `{}`    |    no    |

### Email Template Object

```hcl
{
  name    = string  # Template name
  subject = string  # Email subject (supports variables)
  html    = string  # HTML body (supports variables)
  text    = string  # Plain text body (supports variables)
}
```

## Outputs

| Name                      | Description                           |
| ------------------------- | ------------------------------------- |
| smtp_host                 | SES SMTP host                         |
| smtp_port                 | SES SMTP port                         |
| iam_username              | IAM user name for SES                 |
| smtp_username             | SMTP username (Access Key ID)         |
| smtp_password_secret_arn  | Secrets Manager ARN for SMTP password |
| domain_identity_arn       | SES domain identity ARN               |
| domain_verification_token | Domain verification token             |
| email_templates           | Map of created email templates        |

## SES Sandbox Limitations

New SES accounts are in sandbox mode:

- Can only send to verified email addresses
- Limited sending quota

To move out of sandbox:

1. Go to AWS Console → SES → Account dashboard
2. Click "Request production access"
3. Fill out the request form

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
