# AWS CloudWatch Alarm for RDS Instance Terraform Module

Terraform module which creates CloudWatch alarms for RDS database instances.

## Features

This module supports creating:

- **CPU Utilization Alarms** - Notice and alert thresholds
- **Freeable Memory Alarms** - Memory monitoring
- **Freeable Storage Space Alarms** - Disk space monitoring
- **SNS Integration** - Slack notifications via Chatbot

## Usage

### Example 1: Basic RDS Alarms

```terraform
module "cloudwatch_alarm_rds" {
  source = "../../modules/cloudwatch_alarm_rds_instance"

  app_name                       = "${var.environment}-${var.app_name}-db"
  rds_db_instance_identifier     = module.rds.db_instance_identifier

  cw_alarm_rds_default_evaluation_periods = 5
  cw_alarm_rds_default_period             = 60

  # CPU thresholds
  cw_alarm_rds_cpu_utilization_notice_threshold = 70
  cw_alarm_rds_cpu_utilization_alert_threshold  = 90

  # Memory thresholds (in bytes)
  cw_alarm_rds_freeable_memory_notice_threshold = 150000000  # 150MB
  cw_alarm_rds_freeable_memory_alert_threshold  = 100000000  # 100MB

  # Storage thresholds (in bytes)
  cw_alarm_rds_freeable_storage_space_notice_threshold = 5000000000  # 5GB
  cw_alarm_rds_freeable_storage_space_alert_threshold  = 1000000000  # 1GB

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Production RDS Alarms (Conservative)

```terraform
module "cloudwatch_alarm_rds" {
  source = "../../modules/cloudwatch_alarm_rds_instance"

  app_name                       = "${var.environment}-${var.app_name}-db"
  rds_db_instance_identifier     = module.rds.db_instance_identifier

  # Longer evaluation to avoid false alarms
  cw_alarm_rds_default_evaluation_periods = 10
  cw_alarm_rds_default_period             = 60

  # CPU thresholds
  cw_alarm_rds_cpu_utilization_notice_threshold = 70
  cw_alarm_rds_cpu_utilization_alert_threshold  = 90

  # Memory thresholds (larger buffer for production)
  cw_alarm_rds_freeable_memory_notice_threshold = 500000000   # 500MB
  cw_alarm_rds_freeable_memory_alert_threshold  = 200000000   # 200MB

  # Storage thresholds (larger buffer for production)
  cw_alarm_rds_freeable_storage_space_notice_threshold = 10000000000  # 10GB
  cw_alarm_rds_freeable_storage_space_alert_threshold  = 5000000000   # 5GB

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: Staging RDS Alarms (Quick Response)

```terraform
module "cloudwatch_alarm_rds" {
  source = "../../modules/cloudwatch_alarm_rds_instance"

  app_name                       = "${var.environment}-${var.app_name}-db"
  rds_db_instance_identifier     = module.rds.db_instance_identifier

  # Quick response for staging
  cw_alarm_rds_default_evaluation_periods = 3
  cw_alarm_rds_default_period             = 60

  # Lower thresholds for early detection
  cw_alarm_rds_cpu_utilization_notice_threshold = 50
  cw_alarm_rds_cpu_utilization_alert_threshold  = 70

  cw_alarm_rds_freeable_memory_notice_threshold = 200000000  # 200MB
  cw_alarm_rds_freeable_memory_alert_threshold  = 100000000  # 100MB

  cw_alarm_rds_freeable_storage_space_notice_threshold = 3000000000  # 3GB
  cw_alarm_rds_freeable_storage_space_alert_threshold  = 1000000000  # 1GB

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

## Alarm Thresholds Guide

### CPU Utilization

| Severity | Threshold | Action                           |
| -------- | --------- | -------------------------------- |
| Notice   | 70%       | Monitor, optimize queries        |
| Alert    | 90%       | Scale up, emergency optimization |

### Freeable Memory

| Instance Class | Notice Threshold | Alert Threshold |
| -------------- | ---------------- | --------------- |
| db.t3.micro    | 100MB            | 50MB            |
| db.t3.small    | 200MB            | 100MB           |
| db.t3.medium   | 500MB            | 200MB           |
| db.r6g.large   | 1GB              | 500MB           |

### Freeable Storage Space

| Environment | Notice Threshold | Alert Threshold |
| ----------- | ---------------- | --------------- |
| Development | 2GB              | 1GB             |
| Staging     | 5GB              | 2GB             |
| Production  | 10GB             | 5GB             |

## Byte Conversion Reference

| Size  | Bytes       |
| ----- | ----------- |
| 50MB  | 50000000    |
| 100MB | 100000000   |
| 200MB | 200000000   |
| 500MB | 500000000   |
| 1GB   | 1000000000  |
| 2GB   | 2000000000  |
| 5GB   | 5000000000  |
| 10GB  | 10000000000 |

## Inputs

| Name                                                 | Description                          | Type          | Default | Required |
| ---------------------------------------------------- | ------------------------------------ | ------------- | ------- | :------: |
| app_name                                             | Application name for resource naming | `string`      | n/a     |   yes    |
| rds_db_instance_identifier                           | RDS instance identifier              | `string`      | n/a     |   yes    |
| cw_alarm_rds_default_period                          | Alarm period (seconds)               | `number`      | n/a     |   yes    |
| cw_alarm_rds_default_evaluation_periods              | Evaluation periods                   | `number`      | n/a     |   yes    |
| cw_alarm_rds_cpu_utilization_notice_threshold        | CPU notice threshold (%)             | `number`      | n/a     |   yes    |
| cw_alarm_rds_cpu_utilization_alert_threshold         | CPU alert threshold (%)              | `number`      | n/a     |   yes    |
| cw_alarm_rds_freeable_memory_notice_threshold        | Memory notice threshold (bytes)      | `number`      | n/a     |   yes    |
| cw_alarm_rds_freeable_memory_alert_threshold         | Memory alert threshold (bytes)       | `number`      | n/a     |   yes    |
| cw_alarm_rds_freeable_storage_space_notice_threshold | Storage notice threshold (bytes)     | `number`      | n/a     |   yes    |
| cw_alarm_rds_freeable_storage_space_alert_threshold  | Storage alert threshold (bytes)      | `number`      | n/a     |   yes    |
| chatbot_notice_sns_topic_arn                         | SNS topic ARN for notices            | `string`      | n/a     |   yes    |
| chatbot_alert_sns_topic_arn                          | SNS topic ARN for alerts             | `string`      | n/a     |   yes    |
| tags                                                 | Tags to apply to resources           | `map(string)` | `{}`    |    no    |

## Outputs

This module currently does not export outputs. Alarms are created directly in CloudWatch.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
