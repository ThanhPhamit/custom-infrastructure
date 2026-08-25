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

# ALB 5xx Alarms
# NOTE: every variable below is optional. Existing callers of this module keep
# working unchanged; the 5xx alarms are created by default for ALB deployments.
variable "create_lb_5xx_alarm" {
  description = "Create the ALB 5xx alarms (HTTPCode_ELB_5XX_Count and HTTPCode_Target_5XX_Count). Automatically skipped when load_balancer_type is not alb, because AWS/NetworkELB does not publish these metrics."
  type        = bool
  default     = true
}

variable "cw_alarm_lb_5xx_period" {
  description = "Period for the ALB 5xx alarms (seconds). 300 keeps a single blip from paging while still catching a sustained problem within 5 minutes."
  type        = number
  default     = 300
}

variable "cw_alarm_lb_5xx_evaluation_periods" {
  description = "Evaluation periods for the ALB 5xx alarms."
  type        = number
  default     = 1
}

variable "cw_alarm_lb_elb_5xx_threshold" {
  description = "Alarm when HTTPCode_ELB_5XX_Count exceeds this value within one period. Default 5 absorbs isolated connection blips; set 0 to alert on any single occurrence."
  type        = number
  default     = 5
}

variable "cw_alarm_lb_target_5xx_threshold" {
  description = "Alarm when HTTPCode_Target_5XX_Count exceeds this value within one period. Default 0 alerts on any application-returned 5xx, since a healthy service should sit at zero."
  type        = number
  default     = 0
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

variable "cw_alarm_ecs_log_error_patterns" {
  description = <<-EOT
    One or more CloudWatch Logs metric filter patterns. The module creates
    one metric filter per pattern, and they all publish to the SAME metric
    (CloudWatch Sum aggregation), so a single alarm watches the combined
    count.

    Why a list instead of one string: CloudWatch metric-filter syntax for
    unstructured logs silently drops `?` (OR) groups when combined with `-`
    (NOT) in the same pattern — so `?ERROR ?Exception -"errorMsg"` matches
    every line lacking "errorMsg", regardless of whether ERROR/Exception is
    actually present. The clean workaround is to write each `TERM -"errorMsg"`
    as its own (AND-only) pattern. Patterns are also case-sensitive, so
    enumerate case variants explicitly when needed.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.cw_alarm_ecs_log_error_patterns) > 0
    error_message = "cw_alarm_ecs_log_error_patterns must contain at least one pattern."
  }
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

variable "create_log_error_alarm" {
  description = "If false, the legacy log-error metric filter + alarm are NOT created (Portal owns the enriched replacement). Default true keeps existing behavior."
  type        = bool
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
