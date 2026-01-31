variable "app_name" {}
variable "aws_region" {}

# ECS Scaling Alarms - Periods
variable "cw_alarm_ecs_scale_out_period" {
  description = "Period for ECS scale out alarms (seconds)"
  type        = number
  default     = 60
}

variable "cw_alarm_ecs_scale_in_period" {
  description = "Period for ECS scale in alarms (seconds)"
  type        = number
  default     = 120 # Slower scale-in to prevent flapping
}

variable "cw_alarm_ecs_alert_period" {
  description = "Period for ECS alert-only alarms (seconds)"
  type        = number
  default     = 60
}

# ECS Scaling Alarms - Evaluation Periods
variable "cw_alarm_ecs_scale_out_evaluation_periods" {
  description = "Evaluation periods for scale out alarms"
  type        = number
  default     = 1
}

variable "cw_alarm_ecs_scale_in_evaluation_periods" {
  description = "Evaluation periods for scale in alarms"
  type        = number
  default     = 3
}

variable "cw_alarm_ecs_alert_evaluation_periods" {
  description = "Evaluation periods for alert-only alarms"
  type        = number
  default     = 2
}

# Load Balancer Alarms - Periods and Evaluation Periods
variable "cw_alarm_lb_period" {
  description = "Period for Load Balancer alarms (seconds)"
  type        = number
  default     = 60
}

variable "cw_alarm_lb_evaluation_periods" {
  description = "Evaluation periods for Load Balancer alarms"
  type        = number
  default     = 2
}

# Load Balancer type - determines the namespace for CloudWatch metrics
variable "load_balancer_type" {
  description = "Type of load balancer (alb or nlb)"
  type        = string
  default     = "alb"
  validation {
    condition     = contains(["alb", "nlb"], var.load_balancer_type)
    error_message = "Load balancer type must be either 'alb' or 'nlb'."
  }
}

# Log Error Alarms - Periods and Evaluation Periods
variable "cw_alarm_log_error_period" {
  description = "Period for log error alarms (seconds)"
  type        = number
  default     = 60
}

variable "cw_alarm_log_error_evaluation_periods" {
  description = "Evaluation periods for log error alarms"
  type        = number
  default     = 1
}

variable "cw_alarm_ecs_log_error_pattern" {
  description = "Pattern to match in CloudWatch ecs logs for error detection"
  type        = string
}

# Thresholds
variable "cw_alarm_cluster_name" {}
variable "cw_alarm_service_name" {}
variable "cw_alarm_ecs_memory_utilization_high_threshold" {}
variable "cw_alarm_ecs_memory_utilization_high_alert_threshold" {}
variable "cw_alarm_ecs_memory_utilization_low_threshold" {}
variable "cw_alarm_ecs_cpu_utilization_high_threshold" {}
variable "cw_alarm_ecs_cpu_utilization_high_alert_threshold" {}
variable "cw_alarm_ecs_cpu_utilization_low_threshold" {}

variable "ecs_cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for the ECS service"
}

variable "target_group_blue_id" {}
variable "target_group_green_id" {}
variable "lb_id" {
  description = "Load balancer ID (ALB or NLB ARN suffix)"
}

variable "min_tasks" {}
variable "max_tasks" {}

variable "chatbot_notice_sns_topic_arn" {}
variable "chatbot_alert_sns_topic_arn" {}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
