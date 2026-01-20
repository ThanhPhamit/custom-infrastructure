# Network Module - Sample Usage

## main.tf

```terraform
module "cloudwatch_alarm_elasticache_server_based" {
  source = "../modules/cloudwatch_alarm_elasticache_server_based"

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
  evaluation_periods  = 2   # 2 periods to confirm
  period              = 300 # 5-minute periods
  datapoints_to_alarm = 2   # Both periods must breach

  # Critical alarm settings (aggressive)
  critical_evaluation_periods  = 1  # Single period
  critical_period              = 60 # 1-minute periods
  critical_datapoints_to_alarm = 1  # Single breach triggers

  tags = local.tags
}
```

## variables.tf

```terraform

```

## terraform.tfvars

```hcl

```

## Outputs

```terraform

```
