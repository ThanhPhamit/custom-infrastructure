# Network Module - Sample Usage

## main.tf

```terraform
module "chatbot_slack_notice" {
  source = "../modules/chatbot_slack"

  app_name           = "${var.environment}-${var.app_name}"
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_notice_channel_id
  slack_channel_name = "system-notice"
  tags               = local.tags

  providers = {
    aws   = aws
    awscc = awscc
  }
}
```

## variables.tf

```terraform
variable "slack_workspace_id" {
  type = string
}

variable "slack_notice_channel_id" {
  type = string
}
```

## terraform.tfvars

```hcl
slack_workspace_id      = "T03ARELF1"
slack_notice_channel_id = "C09405LGG2V"
```

## Outputs

```terraform

```
