# CloudWatch Alarms for EventBridge Scheduler

This module creates CloudWatch alarms to monitor EventBridge rules and scheduled events, sending alerts to Slack via AWS Chatbot.

## Features

- **Failed Invocations Monitoring**: Alerts when rule fails to invoke targets
- **Throttled Rules Monitoring**: Alerts when rules are throttled
- **Invocations Heartbeat Monitoring**: Detects when scheduled events stop firing
- **Invocation Errors Monitoring**: Alerts on target invocation failures
- **Dead Letter Queue Monitoring**: Tracks failed event deliveries (optional)

## Usage

```hcl
module "eventbridge_alarms" {
  source = "../../modules/cloudwatch_alarm_eventbridge"

  app_name                    = "remark-ai-tool"
  rule_name                   = "remark-ai-tool-scheduler"
  chatbot_alert_sns_topic_arn = module.chatbot_slack.sns_topic_arn

  # Optional: Enable invocations monitoring (heartbeat)
  enable_invocations_monitoring = true
  invocations_low_period        = 3600 # 1 hour
  invocations_low_threshold     = 1

  # Optional: Enable DLQ monitoring
  enable_dlq_monitoring = false
  # dlq_name            = "remark-ai-tool-dlq"

  tags = local.tags
}
```

## Alarms Created

1. **Failed Invocations Alarm**: Triggers when EventBridge rule fails to invoke targets
2. **Throttled Rules Alarm**: Triggers when rule invocations are throttled
3. **Invocations Low Alarm**: Triggers when scheduled events stop firing (heartbeat)
4. **Invocation Errors Alarm**: Triggers when target invocations fail
5. **DLQ Messages Alarm**: Triggers when messages are sent to Dead Letter Queue (optional)

## Inputs

| Name                          | Description                          | Type   | Default | Required |
| ----------------------------- | ------------------------------------ | ------ | ------- | :------: |
| app_name                      | Application name                     | string | -       |   yes    |
| rule_name                     | EventBridge rule name                | string | -       |   yes    |
| chatbot_alert_sns_topic_arn   | SNS topic ARN for alerts             | string | -       |   yes    |
| enable_invocations_monitoring | Enable heartbeat monitoring          | bool   | true    |    no    |
| invocations_low_period        | Period for heartbeat check (seconds) | number | 3600    |    no    |
| enable_dlq_monitoring         | Enable DLQ monitoring                | bool   | false   |    no    |
| dlq_name                      | Dead Letter Queue name               | string | ""      |    no    |

## Outputs

| Name                         | Description                         |
| ---------------------------- | ----------------------------------- |
| failed_invocations_alarm_arn | ARN of the failed invocations alarm |
| throttled_rules_alarm_arn    | ARN of the throttled rules alarm    |
| invocations_low_alarm_arn    | ARN of the invocations low alarm    |
| invocation_errors_alarm_arn  | ARN of the invocation errors alarm  |
| dlq_messages_alarm_arn       | ARN of the DLQ messages alarm       |

## Important Notes

- **Invocations Low Period**: Set this to match your schedule interval (e.g., 3600 for hourly schedules)
- **Heartbeat Monitoring**: Helps detect when EventBridge rules stop triggering
- **DLQ Monitoring**: Only enable if you have configured a Dead Letter Queue for your rule
