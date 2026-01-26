# AWS Chatbot Slack Integration Terraform Module

Terraform module which creates AWS Chatbot Slack integration for sending notifications.

## Features

This module supports creating:

- **SNS Topic** - Topic for receiving notifications
- **AWS Chatbot** - Slack channel configuration
- **IAM Role** - Chatbot service role with required permissions
- **Notification Integration** - CloudWatch Alarms, CodePipeline, etc.

## Usage

### Example 1: Notice Channel (General Notifications)

```terraform
module "chatbot_slack_notice" {
  source = "../../modules/chatbot_slack"

  app_name           = "${var.environment}-${var.app_name}"
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_notice_channel_id
  slack_channel_name = "system-notice"

  providers = {
    aws   = aws
    awscc = awscc
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 2: Alert Channel (Critical Alerts)

```terraform
module "chatbot_slack_alert" {
  source = "../../modules/chatbot_slack"

  app_name           = "${var.environment}-${var.app_name}"
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_alert_channel_id
  slack_channel_name = "system-alerts"

  providers = {
    aws   = aws
    awscc = awscc
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

### Example 3: Using with CloudWatch Alarms

```terraform
module "chatbot_slack_notice" {
  source = "../../modules/chatbot_slack"

  app_name           = "${var.environment}-${var.app_name}-notice"
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_notice_channel_id
  slack_channel_name = "system-notice"

  providers = {
    aws   = aws
    awscc = awscc
  }

  tags = local.tags
}

# Use with CloudWatch Alarm
module "cloudwatch_alarm_ecs" {
  source = "../../modules/cloudwatch_alarm_ecs"

  # ... other configuration ...

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn
}
```

## Slack Configuration Setup

### Step 1: Get Slack Workspace ID

1. Go to AWS Console → AWS Chatbot
2. Click "Configure new client"
3. Select "Slack" and authorize AWS Chatbot
4. Note the **Workspace ID** (format: `T0XXXXXXX`)

### Step 2: Get Slack Channel ID

1. In Slack, right-click on the channel
2. Select "View channel details"
3. At the bottom, find **Channel ID** (format: `C0XXXXXXXX`)

### Step 3: Invite AWS Chatbot to Channel

```
/invite @aws
```

## Provider Configuration

This module requires both AWS and AWSCC providers:

```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.50.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "awscc" {
  region = "ap-northeast-1"
}
```

## Notification Types

| Source       | Notification Type          |
| ------------ | -------------------------- |
| CloudWatch   | Alarm state changes        |
| CodePipeline | Pipeline execution status  |
| CodeBuild    | Build status notifications |
| Security Hub | Security findings          |
| AWS Health   | Service health events      |

## Inputs

| Name               | Description                            | Type          | Default | Required |
| ------------------ | -------------------------------------- | ------------- | ------- | :------: |
| app_name           | Application name for resource naming   | `string`      | n/a     |   yes    |
| slack_workspace_id | Slack workspace ID (format: T0XXXXXXX) | `string`      | n/a     |   yes    |
| slack_channel_id   | Slack channel ID (format: C0XXXXXXXX)  | `string`      | n/a     |   yes    |
| slack_channel_name | Slack channel name for identification  | `string`      | n/a     |   yes    |
| tags               | Tags to apply to resources             | `map(string)` | `{}`    |    no    |

## Outputs

| Name                  | Description                      |
| --------------------- | -------------------------------- |
| chatbot_sns_topic_arn | ARN of the SNS topic for Chatbot |

## Best Practices

1. **Separate Channels**: Use different channels for notices vs alerts
2. **Channel Naming**: Use descriptive names like `#aws-staging-alerts`
3. **Alert Fatigue**: Configure appropriate alarm thresholds to avoid noise
4. **Permissions**: Limit who can acknowledge/silence alerts

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 1.4.0  |
| aws       | >= 5.0.0  |
| awscc     | >= 0.50.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
