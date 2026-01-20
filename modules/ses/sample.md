# Network Module - Sample Usage

## main.tf

```terraform
module "ses" {
  source = "../modules/ses"

  app_name         = "${var.environment}-${var.app_name}"
  email_identities = []
  create_smtp_user = false

  email_templates = var.email_templates

  tags = local.tags
}
```

## variables.tf

```terraform
variable "email_templates" {
  description = "List of email templates to create in SES"
  type = list(object({
    name    = string
    subject = string
    html    = string
    text    = string
  }))
  default = []
}
```

## terraform.tfvars

```hcl
email_templates = [
  {
    name    = "stg-fid-contact-template"
    subject = "【FocusiDESIGNお問い合わせ通知】新しいお問い合わせがありました"
    html    = <<EOF
<p>以下の内容でお問い合わせがありました。<br>
ご確認の上、対応をお願いいたします。</p>

<hr>
<p>
■会社名: {{company_name}}<br>
■ご氏名: {{contact_name}}<br>
■電話番号: {{phone}}<br>
■メールアドレス: {{email}}<br>
■お問い合わせ種類: {{inquiry_type}}<br>
■お問い合わせ内容: {{message}}
</p>
<hr>

<p>本メールはお問い合わせフォームから自動送信されています。</p>
EOF
    text    = <<EOF
以下の内容でお問い合わせがありました。\n
ご確認の上、対応をお願いいたします。\n
\n
------------------------------------------------------------\n
■会社名: {{company_name}}\n
■ご氏名: {{contact_name}}\n
■電話番号: {{phone}}\n
■メールアドレス: {{email}}\n
■お問い合わせ種類: {{inquiry_type}}\n
■お問い合わせ内容: {{message}}\n
------------------------------------------------------------\n
\n
本メールはお問い合わせフォームから自動送信されています。\n
EOF
  },
  {
    name    = "stg-fid-career-template"
    subject = "【FocusiDESIGNキャリア相談申込通知】新しいお申し込みがありました"
    html    = <<EOF
<p>以下の内容でキャリア相談のお申し込みがありました。<br>
ご確認の上、対応をお願いいたします。</p>

<hr>
<p>
■ご氏名（漢字）: {{name}}<br>
■ご氏名（カナ）: {{name_kana}}<br>
■生年月日: {{birth_date}}<br>
■電話番号: {{phone}}<br>
■メールアドレス: {{email}}<br>
■お問い合わせ内容: {{message}}
</p>
<hr>

<p>本メールはキャリア相談お申し込みフォームから自動送信されています。</p>
EOF

    text = <<EOF
以下の内容でキャリア相談のお申し込みがありました。\n
ご確認の上、対応をお願いいたします。\n
\n
------------------------------------------------------------\n
■ご氏名（漢字）: {{name}}\n
■ご氏名（カナ）: {{name_kana}}\n
■生年月日: {{birth_date}}\n
■電話番号: {{phone}}\n
■メールアドレス: {{email}}\n
■お問い合わせ内容: {{message}}\n
------------------------------------------------------------\n
\n
本メールはキャリア相談お申し込みフォームから自動送信されています。\n
EOF
  }
]
```

## Outputs

```terraform

```
