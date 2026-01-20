# Network Module - Sample Usage

## main.tf

```terraform
module "cloudwatch_alarm_ecs_nest" {
  source = "../modules/cloudwatch_alarm_ecs"

  app_name                     = "${var.environment}-${var.app_name}-nest"
  aws_region                   = var.region
  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  cw_alarm_cluster_name = module.ecs_cluster_nest.cluster_name
  cw_alarm_service_name = module.ecs_nest.service_name

  cw_alarm_ecs_scale_out_period = 60
  cw_alarm_ecs_scale_in_period  = 60
  cw_alarm_ecs_alert_period     = 60

  cw_alarm_ecs_scale_out_evaluation_periods = 1
  cw_alarm_ecs_scale_in_evaluation_periods  = 5
  cw_alarm_ecs_alert_evaluation_periods     = 5

  load_balancer_type             = "nlb"
  cw_alarm_lb_period             = 60
  cw_alarm_lb_evaluation_periods = 1

  cw_alarm_log_error_period             = 60
  cw_alarm_log_error_evaluation_periods = 1

  cw_alarm_ecs_memory_utilization_high_threshold       = 70
  cw_alarm_ecs_memory_utilization_high_alert_threshold = 90
  cw_alarm_ecs_memory_utilization_low_threshold        = 20
  cw_alarm_ecs_cpu_utilization_high_threshold          = 70
  cw_alarm_ecs_cpu_utilization_high_alert_threshold    = 90
  cw_alarm_ecs_cpu_utilization_low_threshold           = 20

  target_group_blue_id  = module.ecs_nest.lb_target_group_blue_arn_suffix
  target_group_green_id = module.ecs_nest.lb_target_group_green_arn_suffix
  lb_id                 = module.elb_nest.nlb_arn_suffix


  max_tasks = var.ecs_nest_max_tasks
  min_tasks = var.ecs_nest_min_tasks

  ecs_cloudwatch_log_group_name  = module.ecs_nest.ecs_cloudwatch_log_group_name
  cw_alarm_ecs_log_error_pattern = "InternalServerErrorException ?ERROR ?error ?CRITICAL ?Exception ?Traceback ?\"❌\""
  tags                           = local.tags
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
