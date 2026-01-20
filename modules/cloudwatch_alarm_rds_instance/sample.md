# Network Module - Sample Usage

## main.tf

```terraform
module "cloudwatch_alarm_rds" {
  source = "../modules/cloudwatch_alarm_rds"

  app_name                                             = "${var.environment}-${var.app_name}-server"
  rds_db_instance_identifier                           = module.rds.identifier
  cw_alarm_rds_default_evaluation_periods              = 10
  cw_alarm_rds_default_period                          = 60
  cw_alarm_rds_cpu_utilization_notice_threshold        = 70
  cw_alarm_rds_cpu_utilization_alert_threshold         = 90
  cw_alarm_rds_freeable_memory_notice_threshold        = 150000000  # 150MB
  cw_alarm_rds_freeable_memory_alert_threshold         = 100000000  # 100MB
  cw_alarm_rds_freeable_storage_space_notice_threshold = 5000000000 # 5G
  cw_alarm_rds_freeable_storage_space_alert_threshold  = 1000000000 # 1G

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn
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
