# CloudWatch Alarms for ECS Scheduled Task

This module creates CloudWatch alarms to monitor ECS scheduled tasks and send alerts to Slack via AWS Chatbot.

## Features

- **Task Failure Monitoring**: Alerts when scheduled tasks fail to run
- **Task Stopped Monitoring**: Alerts when tasks stop unexpectedly
- **CPU Utilization Monitoring**: Alerts when CPU usage exceeds threshold
- **Memory Utilization Monitoring**: Alerts when memory usage exceeds threshold
- **Log Error Monitoring**: Detects and alerts on errors in CloudWatch logs

## Usage

```hcl
module "ecs_scheduled_task_alarms" {
  source = "../../modules/cloudwatch_alarm_ecs_scheduled_task"

  app_name                    = "remark-ai-tool"
  cluster_name                = "remark-ai-tool"
  log_group_name              = "/ecs/remark-ai-tool"
  chatbot_alert_sns_topic_arn = module.chatbot_slack.sns_topic_arn

  # Optional: Customize thresholds
  cpu_high_threshold    = 80
  memory_high_threshold = 80

  # Optional: Customize monitoring periods
  task_failed_period = 300
  cpu_period         = 300
  memory_period      = 300

  tags = local.tags
}
```

## Alarms Created

1. **Task Failed Alarm**: Triggers when tasks fail to run successfully
2. **Task Stopped Alarm**: Triggers when tasks stop unexpectedly
3. **CPU High Alarm**: Triggers when CPU utilization exceeds threshold
4. **Memory High Alarm**: Triggers when memory utilization exceeds threshold
5. **Log Errors Alarm**: Triggers when errors are detected in logs

## Inputs

| Name                        | Description                      | Type   | Default | Required |
| --------------------------- | -------------------------------- | ------ | ------- | :------: |
| app_name                    | Application name                 | string | -       |   yes    |
| cluster_name                | ECS cluster name                 | string | -       |   yes    |
| log_group_name              | CloudWatch log group name        | string | -       |   yes    |
| chatbot_alert_sns_topic_arn | SNS topic ARN for alerts         | string | -       |   yes    |
| cpu_high_threshold          | CPU utilization threshold (%)    | number | 80      |    no    |
| memory_high_threshold       | Memory utilization threshold (%) | number | 80      |    no    |
| enable_log_error_monitoring | Enable log error monitoring      | bool   | true    |    no    |

## Outputs

| Name                   | Description                   |
| ---------------------- | ----------------------------- |
| task_failed_alarm_arn  | ARN of the task failed alarm  |
| task_stopped_alarm_arn | ARN of the task stopped alarm |
| cpu_high_alarm_arn     | ARN of the CPU high alarm     |
| memory_high_alarm_arn  | ARN of the memory high alarm  |
| log_errors_alarm_arn   | ARN of the log errors alarm   |
