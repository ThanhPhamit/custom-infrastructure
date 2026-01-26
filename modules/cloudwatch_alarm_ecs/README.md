# AWS CloudWatch Alarm for ECS Terraform Module

Terraform module which creates CloudWatch alarms for ECS services with auto-scaling and alerting.

## Features

This module supports creating:

- **CPU Utilization Alarms** - Scale out/in and alert thresholds
- **Memory Utilization Alarms** - Scale out/in and alert thresholds
- **Load Balancer Alarms** - Unhealthy host count monitoring
- **Log Error Alarms** - Application error detection
- **Auto Scaling Policies** - Target tracking and step scaling
- **SNS Integration** - Slack notifications via Chatbot

## Usage

### Example 1: Basic ECS Alarms with ALB

```terraform
module "cloudwatch_alarm_ecs" {
  source = "../../modules/cloudwatch_alarm_ecs"

  app_name   = "${var.environment}-${var.app_name}-api"
  aws_region = var.region

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  cw_alarm_cluster_name = module.ecs_cluster.cluster_name
  cw_alarm_service_name = module.ecs_api.service_name

  # Scaling periods
  cw_alarm_ecs_scale_out_period = 60
  cw_alarm_ecs_scale_in_period  = 60
  cw_alarm_ecs_alert_period     = 60

  # Evaluation periods
  cw_alarm_ecs_scale_out_evaluation_periods = 1
  cw_alarm_ecs_scale_in_evaluation_periods  = 5
  cw_alarm_ecs_alert_evaluation_periods     = 5

  # Load balancer
  load_balancer_type             = "alb"
  cw_alarm_lb_period             = 60
  cw_alarm_lb_evaluation_periods = 1

  # Log error monitoring
  cw_alarm_log_error_period             = 60
  cw_alarm_log_error_evaluation_periods = 1

  # Thresholds
  cw_alarm_ecs_memory_utilization_high_threshold       = 70
  cw_alarm_ecs_memory_utilization_high_alert_threshold = 90
  cw_alarm_ecs_memory_utilization_low_threshold        = 20
  cw_alarm_ecs_cpu_utilization_high_threshold          = 70
  cw_alarm_ecs_cpu_utilization_high_alert_threshold    = 90
  cw_alarm_ecs_cpu_utilization_low_threshold           = 20

  # Target groups
  target_group_blue_id  = module.ecs_api.lb_target_group_blue_arn_suffix
  target_group_green_id = module.ecs_api.lb_target_group_green_arn_suffix
  lb_id                 = module.alb.alb_arn_suffix

  # Auto scaling limits
  max_tasks = var.ecs_api_max_tasks
  min_tasks = var.ecs_api_min_tasks

  # Log monitoring
  ecs_cloudwatch_log_group_name  = module.ecs_api.ecs_cloudwatch_log_group_name
  cw_alarm_ecs_log_error_pattern = "ERROR ?error ?CRITICAL ?Exception ?Traceback"

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: ECS Alarms with NLB

```terraform
module "cloudwatch_alarm_ecs" {
  source = "../../modules/cloudwatch_alarm_ecs"

  app_name   = "${var.environment}-${var.app_name}-nest"
  aws_region = var.region

  chatbot_notice_sns_topic_arn = module.chatbot_slack_notice.chatbot_sns_topic_arn
  chatbot_alert_sns_topic_arn  = module.chatbot_slack_alert.chatbot_sns_topic_arn

  cw_alarm_cluster_name = module.ecs_cluster.cluster_name
  cw_alarm_service_name = module.ecs_nest.service_name

  # Scaling configuration
  cw_alarm_ecs_scale_out_period              = 60
  cw_alarm_ecs_scale_in_period               = 60
  cw_alarm_ecs_alert_period                  = 60
  cw_alarm_ecs_scale_out_evaluation_periods  = 1
  cw_alarm_ecs_scale_in_evaluation_periods   = 5
  cw_alarm_ecs_alert_evaluation_periods      = 5

  # NLB configuration
  load_balancer_type             = "nlb"
  cw_alarm_lb_period             = 60
  cw_alarm_lb_evaluation_periods = 1

  # Log monitoring
  cw_alarm_log_error_period             = 60
  cw_alarm_log_error_evaluation_periods = 1

  # Thresholds
  cw_alarm_ecs_memory_utilization_high_threshold       = 70
  cw_alarm_ecs_memory_utilization_high_alert_threshold = 90
  cw_alarm_ecs_memory_utilization_low_threshold        = 20
  cw_alarm_ecs_cpu_utilization_high_threshold          = 70
  cw_alarm_ecs_cpu_utilization_high_alert_threshold    = 90
  cw_alarm_ecs_cpu_utilization_low_threshold           = 20

  # Target groups and NLB
  target_group_blue_id  = module.ecs_nest.lb_target_group_blue_arn_suffix
  target_group_green_id = module.ecs_nest.lb_target_group_green_arn_suffix
  lb_id                 = module.nlb.nlb_arn_suffix

  # Auto scaling
  max_tasks = var.ecs_nest_max_tasks
  min_tasks = var.ecs_nest_min_tasks

  # Log error detection
  ecs_cloudwatch_log_group_name  = module.ecs_nest.ecs_cloudwatch_log_group_name
  cw_alarm_ecs_log_error_pattern = "InternalServerErrorException ?ERROR ?error ?CRITICAL ?Exception ?Traceback ?\"❌\""

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}
```

## Alarm Thresholds Guide

### CPU Utilization

| Alarm Type | Threshold | Action              |
| ---------- | --------- | ------------------- |
| Scale Out  | 70%       | Add ECS tasks       |
| Alert      | 90%       | Send critical alert |
| Scale In   | 20%       | Remove ECS tasks    |

### Memory Utilization

| Alarm Type | Threshold | Action              |
| ---------- | --------- | ------------------- |
| Scale Out  | 70%       | Add ECS tasks       |
| Alert      | 90%       | Send critical alert |
| Scale In   | 20%       | Remove ECS tasks    |

## Log Error Pattern Examples

```hcl
# Node.js/NestJS
cw_alarm_ecs_log_error_pattern = "InternalServerErrorException ?ERROR ?error ?CRITICAL ?Exception"

# Python/Django
cw_alarm_ecs_log_error_pattern = "ERROR ?error ?CRITICAL ?Exception ?Traceback"

# Java/Spring
cw_alarm_ecs_log_error_pattern = "ERROR ?Exception ?FATAL ?java.lang"

# General
cw_alarm_ecs_log_error_pattern = "ERROR ?error ?CRITICAL ?FATAL ?Exception"
```

## Inputs

| Name                                                 | Description                          | Type          | Default | Required |
| ---------------------------------------------------- | ------------------------------------ | ------------- | ------- | :------: |
| app_name                                             | Application name for resource naming | `string`      | n/a     |   yes    |
| aws_region                                           | AWS region                           | `string`      | n/a     |   yes    |
| cw_alarm_cluster_name                                | ECS cluster name                     | `string`      | n/a     |   yes    |
| cw_alarm_service_name                                | ECS service name                     | `string`      | n/a     |   yes    |
| chatbot_notice_sns_topic_arn                         | SNS topic ARN for notices            | `string`      | n/a     |   yes    |
| chatbot_alert_sns_topic_arn                          | SNS topic ARN for alerts             | `string`      | n/a     |   yes    |
| target_group_blue_id                                 | Blue target group ARN suffix         | `string`      | n/a     |   yes    |
| target_group_green_id                                | Green target group ARN suffix        | `string`      | n/a     |   yes    |
| lb_id                                                | Load balancer ARN suffix             | `string`      | n/a     |   yes    |
| min_tasks                                            | Minimum number of ECS tasks          | `number`      | n/a     |   yes    |
| max_tasks                                            | Maximum number of ECS tasks          | `number`      | n/a     |   yes    |
| ecs_cloudwatch_log_group_name                        | CloudWatch log group name            | `string`      | n/a     |   yes    |
| cw_alarm_ecs_log_error_pattern                       | Log error pattern to match           | `string`      | n/a     |   yes    |
| load_balancer_type                                   | Load balancer type (alb or nlb)      | `string`      | `"alb"` |    no    |
| cw_alarm_ecs_scale_out_period                        | Scale out alarm period (seconds)     | `number`      | `30`    |    no    |
| cw_alarm_ecs_scale_in_period                         | Scale in alarm period (seconds)      | `number`      | `60`    |    no    |
| cw_alarm_ecs_scale_out_evaluation_periods            | Scale out evaluation periods         | `number`      | `1`     |    no    |
| cw_alarm_ecs_scale_in_evaluation_periods             | Scale in evaluation periods          | `number`      | `3`     |    no    |
| cw_alarm_ecs_cpu_utilization_high_threshold          | CPU high threshold for scaling       | `number`      | `70`    |    no    |
| cw_alarm_ecs_cpu_utilization_high_alert_threshold    | CPU high threshold for alert         | `number`      | `90`    |    no    |
| cw_alarm_ecs_cpu_utilization_low_threshold           | CPU low threshold for scale in       | `number`      | `20`    |    no    |
| cw_alarm_ecs_memory_utilization_high_threshold       | Memory high threshold for scaling    | `number`      | `70`    |    no    |
| cw_alarm_ecs_memory_utilization_high_alert_threshold | Memory high threshold for alert      | `number`      | `90`    |    no    |
| cw_alarm_ecs_memory_utilization_low_threshold        | Memory low threshold for scale in    | `number`      | `20`    |    no    |
| tags                                                 | Tags to apply to resources           | `map(string)` | `{}`    |    no    |

## Outputs

This module does not have outputs. Alarms and scaling policies are created directly.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
