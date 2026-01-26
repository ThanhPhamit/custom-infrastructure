# AWS CloudWatch Alarm for ElastiCache (Server-Based) Terraform Module

Terraform module which creates CloudWatch alarms for ElastiCache Redis/Valkey clusters.

## Features

This module supports creating:

- **CPU Utilization Alarms** - Warning and critical thresholds
- **Memory Utilization Alarms** - Warning and critical thresholds
- **Per-Node Monitoring** - Individual alarms for each cache node
- **SNS Integration** - Slack notifications via Chatbot

## Usage

### Example 1: Basic ElastiCache Alarms

```terraform
module "cloudwatch_alarm_elasticache" {
  source = "../../modules/cloudwatch_alarm_elasticache_server_based"

  app_name    = "${var.environment}-${var.app_name}"
  aws_region  = var.region
  cache_nodes = module.elasticache_server_based.cache_nodes

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  # CPU thresholds
  cpu_utilization_warning_threshold  = 70
  cpu_utilization_critical_threshold = 90

  # Memory thresholds
  database_memory_usage_warning_threshold  = 70
  database_memory_usage_critical_threshold = 90

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Conservative Alarm Settings (Production)

```terraform
module "cloudwatch_alarm_elasticache" {
  source = "../../modules/cloudwatch_alarm_elasticache_server_based"

  app_name    = "${var.environment}-${var.app_name}"
  aws_region  = var.region
  cache_nodes = module.elasticache_server_based.cache_nodes

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  # CPU thresholds
  cpu_utilization_warning_threshold  = 70
  cpu_utilization_critical_threshold = 90

  # Memory thresholds
  database_memory_usage_warning_threshold  = 70
  database_memory_usage_critical_threshold = 90

  # Warning alarm settings (conservative)
  evaluation_periods  = 2    # 2 periods to confirm
  period              = 300  # 5-minute periods
  datapoints_to_alarm = 2    # Both periods must breach

  # Critical alarm settings (aggressive)
  critical_evaluation_periods  = 1   # Single period
  critical_period              = 60  # 1-minute periods
  critical_datapoints_to_alarm = 1   # Single breach triggers

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 3: Aggressive Monitoring (Staging/Testing)

```terraform
module "cloudwatch_alarm_elasticache" {
  source = "../../modules/cloudwatch_alarm_elasticache_server_based"

  app_name    = "${var.environment}-${var.app_name}"
  aws_region  = var.region
  cache_nodes = module.elasticache_server_based.cache_nodes

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  # Lower thresholds for early detection
  cpu_utilization_warning_threshold  = 50
  cpu_utilization_critical_threshold = 70

  database_memory_usage_warning_threshold  = 50
  database_memory_usage_critical_threshold = 70

  # Quick response settings
  evaluation_periods  = 1
  period              = 60
  datapoints_to_alarm = 1

  critical_evaluation_periods  = 1
  critical_period              = 60
  critical_datapoints_to_alarm = 1

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

## Alarm Thresholds Guide

### CPU Utilization

| Severity | Threshold | Recommendation               |
| -------- | --------- | ---------------------------- |
| Warning  | 70%       | Monitor and plan for scaling |
| Critical | 90%       | Immediate action required    |

### Memory Utilization

| Severity | Threshold | Recommendation                    |
| -------- | --------- | --------------------------------- |
| Warning  | 70%       | Review eviction policies          |
| Critical | 90%       | Scale up or optimize data storage |

## Alarm Period Recommendations

| Environment | Warning Period   | Critical Period | Use Case                 |
| ----------- | ---------------- | --------------- | ------------------------ |
| Production  | 5 minutes (300s) | 1 minute (60s)  | Stable, confirmed alerts |
| Staging     | 1 minute (60s)   | 1 minute (60s)  | Quick feedback           |
| Development | 1 minute (60s)   | 1 minute (60s)  | Fast iteration           |

## Inputs

| Name                                     | Description                          | Type          | Default | Required |
| ---------------------------------------- | ------------------------------------ | ------------- | ------- | :------: |
| app_name                                 | Application name for resource naming | `string`      | n/a     |   yes    |
| aws_region                               | AWS region                           | `string`      | n/a     |   yes    |
| cache_nodes                              | Map of cache nodes with details      | `map(object)` | n/a     |   yes    |
| chatbot_notice_sns_topic_arn             | SNS topic ARN for notices            | `string`      | n/a     |   yes    |
| chatbot_alert_sns_topic_arn              | SNS topic ARN for alerts             | `string`      | n/a     |   yes    |
| cpu_utilization_warning_threshold        | CPU warning threshold                | `number`      | `70`    |    no    |
| cpu_utilization_critical_threshold       | CPU critical threshold               | `number`      | `90`    |    no    |
| database_memory_usage_warning_threshold  | Memory warning threshold             | `number`      | `80`    |    no    |
| database_memory_usage_critical_threshold | Memory critical threshold            | `number`      | `95`    |    no    |
| evaluation_periods                       | Warning alarm evaluation periods     | `number`      | `2`     |    no    |
| period                                   | Warning alarm period (seconds)       | `number`      | `300`   |    no    |
| datapoints_to_alarm                      | Warning datapoints required          | `number`      | `2`     |    no    |
| critical_evaluation_periods              | Critical alarm evaluation periods    | `number`      | `1`     |    no    |
| critical_period                          | Critical alarm period (seconds)      | `number`      | `60`    |    no    |
| critical_datapoints_to_alarm             | Critical datapoints required         | `number`      | `1`     |    no    |
| tags                                     | Tags to apply to resources           | `map(string)` | `{}`    |    no    |

## Cache Nodes Input Format

The `cache_nodes` input expects a map from the `elasticache_server_based` module:

```hcl
cache_nodes = {
  "node-0001" = {
    address    = "my-cluster-0001.abc123.apne1.cache.amazonaws.com"
    az         = "ap-northeast-1a"
    cluster_id = "my-cluster"
    node_id    = "0001"
    port       = 6379
  }
}
```

## Outputs

This module currently does not export outputs. Alarms are created directly in CloudWatch.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
