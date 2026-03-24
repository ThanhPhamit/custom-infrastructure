# Alert Email Module

Reusable **SNS → Lambda → SES** email gateway. Produces clean HTML emails
without SNS unsubscribe links.

## Architecture

```
┌──────────────────┐
│ CloudWatch Alarms│──┐
├──────────────────┤  │
│ AWS WAF          │──┤
├──────────────────┤  │   ┌──────────────┐   ┌─────────┐   ┌───────────┐
│ RDS / Aurora     │──┤──▶│  SNS Topic   │──▶│ Lambda  │──▶│    SES    │──▶ Email
├──────────────────┤  │   │  (shared)    │   │ (format)│   │  (clean)  │
│ ECS / Fargate    │──┤   └──────────────┘   └─────────┘   └───────────┘
├──────────────────┤  │          ▲
│ Lambda / App     │──┤          │
├──────────────────┤  │   ┌──────────────┐
│ EventBridge      │──┘   │ SDK / CLI    │
├──────────────────┤      │ aws sns      │
│ S3 Events        │──────│ publish ...  │
├──────────────────┤      └──────────────┘
│ CodePipeline     │──┘
└──────────────────┘
```

Any AWS service or application in the account can publish to the SNS topic.
Lambda renders the message into a branded HTML email and sends it through SES.

## Compatible Services

Any service that can publish to SNS can use this module. Common use-cases:

| Service                      | Use-case                                                                   | How to connect                                                |
| ---------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **CloudWatch Alarms**        | CPU/Memory/Error-rate thresholds, WAF blocked requests, RDS connections    | Set `alarm_actions = [module.alert_email.sns_topic_arn]`      |
| **AWS WAF**                  | Blocked/counted request spikes (via CloudWatch Alarms)                     | Already wired through `waf_monitoring` module                 |
| **EventBridge Rules**        | Scheduled events, AWS Health events, EC2 state changes, GuardDuty findings | Target = SNS topic ARN                                        |
| **RDS / Aurora**             | Event subscriptions (failover, maintenance, snapshot)                      | `aws_db_event_subscription { sns_topic = ... }`               |
| **ECS / Fargate**            | Task stopped, deployment failures (via EventBridge)                        | EventBridge rule → SNS topic                                  |
| **S3**                       | Bucket notifications (upload, delete, replication failure)                 | `aws_s3_bucket_notification { topic { topic_arn = ... } }`    |
| **CodePipeline / CodeBuild** | Pipeline failures, build status changes                                    | EventBridge rule or notification rule → SNS                   |
| **AWS Budgets**              | Cost threshold alerts                                                      | `aws_budgets_budget { notification { sns_topic_arn = ... } }` |
| **AWS Health**               | Scheduled maintenance, service degradation                                 | EventBridge rule for `aws.health` source                      |
| **GuardDuty**                | Threat detection findings                                                  | EventBridge rule for `aws.guardduty` source                   |
| **AWS Backup**               | Backup job failures                                                        | EventBridge rule for `aws.backup` source                      |
| **Elastic Load Balancer**    | Unhealthy target count (via CloudWatch Alarm)                              | Alarm → SNS topic                                             |
| **Lambda Functions**         | Application-level alerts from your own code                                | `boto3: sns.publish(TopicArn=..., Message=...)`               |
| **Secrets Manager**          | Rotation failure events                                                    | EventBridge rule for `aws.secretsmanager`                     |
| **ACM**                      | Certificate expiration approaching                                         | EventBridge rule for `aws.acm` source                         |

### Example: EventBridge → SNS (GuardDuty findings)

```hcl
resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "guardduty-high-severity"
  description = "GuardDuty findings with severity >= HIGH"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail      = { severity = [{ numeric = [">=", 7] }] }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_email" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "send-to-alert-email"
  arn       = module.alert_email.sns_topic_arn
}
```

### Example: SDK publish from application code

```python
import boto3, json

sns = boto3.client("sns")
sns.publish(
    TopicArn="arn:aws:sns:ap-northeast-3:123456789012:prod-myapp-alerts",
    Subject="Deployment Complete",
    Message=json.dumps({
        "environment": "production",
        "version": "v2.4.1",
        "status": "SUCCESS"
    }),
)
```

## Features

- **CloudWatch Alarm support** – auto-detects alarm JSON payloads and renders
  a structured table (state badge, metric details, dimensions, reason).
- **Generic message support** – any text/JSON message gets a clean layout.
- **No unsubscribe link** – emails are sent directly via SES, not SNS email
  protocol.
- **Reusable** – expose `sns_topic_arn` to any module/service that needs to
  send email alerts.
- **SES region override** – deploy in regions where SES is unavailable by
  pointing Lambda to a different SES region.

## Usage

```hcl
module "alert_email" {
  source           = "../../modules/alert_email"
  app_name         = "prod-myapp"
  sender_email     = "noreply@example.com"
  recipient_emails = ["ops@example.com"]
  ses_region       = "ap-northeast-1"   # optional override
  tags             = local.tags
}

# Pass the topic ARN to any module that needs to send alerts
module "waf_monitoring" {
  source        = "../../modules/waf_monitoring"
  sns_topic_arn = module.alert_email.sns_topic_arn
  # …
}
```

## Prerequisites

1. **SES sender verification** – The `sender_email` address (or its domain)
   must be verified in SES. Set `create_ses_identity = true` (default) to
   have the module create the identity; AWS will send a verification email.
2. **SES production access** – If the account is still in SES sandbox mode,
   recipient addresses must also be verified. Request production access via
   the AWS Console → SES → Account dashboard.

## Inputs

| Name                        | Type           | Default | Description                                   |
| --------------------------- | -------------- | ------- | --------------------------------------------- |
| `app_name`                  | `string`       | —       | Resource name prefix                          |
| `sender_email`              | `string`       | —       | Verified SES From address                     |
| `recipient_emails`          | `list(string)` | —       | Destination email addresses                   |
| `ses_region`                | `string`       | `""`    | SES region override (empty = provider region) |
| `create_ses_identity`       | `bool`         | `true`  | Create SES email identity for sender          |
| `lambda_log_retention_days` | `number`       | `14`    | Lambda log retention                          |
| `tags`                      | `map(string)`  | `{}`    | Tags                                          |

## Outputs

| Name                   | Description                                |
| ---------------------- | ------------------------------------------ |
| `sns_topic_arn`        | ARN of the SNS topic (publish alerts here) |
| `sns_topic_name`       | Name of the SNS topic                      |
| `lambda_function_arn`  | ARN of the forwarder Lambda                |
| `lambda_function_name` | Name of the forwarder Lambda               |
