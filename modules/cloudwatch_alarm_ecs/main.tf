# Auto-scaling settings
resource "aws_appautoscaling_target" "ecs_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cw_alarm_cluster_name}/${var.cw_alarm_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-autoscaling-target"
    }
  )
}

resource "aws_appautoscaling_policy" "scale_out" {
  name               = "${var.app_name}-ecs-scale-out"
  policy_type        = "StepScaling"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "scale_in" {
  name               = "${var.app_name}-ecs-scale-in"
  policy_type        = "StepScaling"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# About Memory
# Automatically scale when usage exceeds the threshold
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization_high" {
  alarm_name          = "${var.app_name}_ecs_memory_utilization_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_scale_out_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_scale_out_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_memory_utilization_high_threshold
  alarm_description   = "ECS Memory Utilization is too high."
  alarm_actions       = [aws_appautoscaling_policy.scale_out.arn, var.chatbot_notice_sns_topic_arn]
  ok_actions          = [var.chatbot_notice_sns_topic_arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-memory-utilization-high"
    }
  )
}

# Memory Alert Settings
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization_high_alert" {
  alarm_name          = "${var.app_name}_ecs_memory_utilization_high_alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_alert_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_alert_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_memory_utilization_high_alert_threshold
  alarm_description   = "ECS Memory Utilization is too high."
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  ok_actions          = [var.chatbot_alert_sns_topic_arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-memory-utilization-high-alert"
    }
  )
}

# When usage falls below the threshold
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization_low" {
  alarm_name          = "${var.app_name}_ecs_memory_utilization_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_scale_in_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_scale_in_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_memory_utilization_low_threshold
  alarm_description   = "ECS Memory Utilization is low."
  alarm_actions       = [aws_appautoscaling_policy.scale_in.arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-memory-utilization-low"
    }
  )
}

# CPU
# Auto-scale when usage exceeds the threshold
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization_high" {
  alarm_name          = "${var.app_name}_ecs_cpu_utilization_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_scale_out_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_scale_out_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_cpu_utilization_high_threshold
  alarm_description   = "ECS CPU Utilization is too high"
  alarm_actions       = [aws_appautoscaling_policy.scale_out.arn, var.chatbot_notice_sns_topic_arn]
  ok_actions          = [var.chatbot_notice_sns_topic_arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-cpu-utilization-high"
    }
  )
}

# CPU usage alert
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization_high_alert" {
  alarm_name          = "${var.app_name}_ecs_cpu_utilization_high_alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_alert_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_alert_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_cpu_utilization_high_alert_threshold
  alarm_description   = "ECS CPU Utilization is too high"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  ok_actions          = [var.chatbot_alert_sns_topic_arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-cpu-utilization-high-alert"
    }
  )
}

# When CPU usage falls below the threshold
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization_low" {
  alarm_name          = "${var.app_name}_ecs_cpu_utilization_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.cw_alarm_ecs_scale_in_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.cw_alarm_ecs_scale_in_period
  statistic           = "Average"
  threshold           = var.cw_alarm_ecs_cpu_utilization_low_threshold
  alarm_description   = "ECS CPU Utilization is low."
  alarm_actions       = [aws_appautoscaling_policy.scale_in.arn]
  dimensions = {
    ClusterName = var.cw_alarm_cluster_name
    ServiceName = var.cw_alarm_service_name
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-cpu-utilization-low"
    }
  )
}


# When there are no healthy tasks associated with the Load Balancer, trigger an alert.
resource "aws_cloudwatch_metric_alarm" "lb_healthy_count_blue" {
  alarm_name                = "${var.app_name}_${var.load_balancer_type}_healthy_count_blue"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = var.cw_alarm_lb_evaluation_periods
  metric_name               = "HealthyHostCount"
  namespace                 = var.load_balancer_type == "alb" ? "AWS/ApplicationELB" : "AWS/NetworkELB"
  period                    = var.cw_alarm_lb_period
  statistic                 = "Minimum"
  threshold                 = 1
  alarm_description         = "${upper(var.load_balancer_type)} blue target group healthy count is less than 1."
  treat_missing_data        = "breaching"
  alarm_actions             = [] # No actions - used by composite alarm
  ok_actions                = []
  insufficient_data_actions = []
  dimensions = {
    TargetGroup  = var.target_group_blue_id
    LoadBalancer = var.lb_id
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.load_balancer_type}-healthy-count-blue"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "lb_healthy_count_green" {
  alarm_name                = "${var.app_name}_${var.load_balancer_type}_healthy_count_green"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = var.cw_alarm_lb_evaluation_periods
  metric_name               = "HealthyHostCount"
  namespace                 = var.load_balancer_type == "alb" ? "AWS/ApplicationELB" : "AWS/NetworkELB"
  period                    = var.cw_alarm_lb_period
  statistic                 = "Minimum"
  threshold                 = 1
  alarm_description         = "${upper(var.load_balancer_type)} green target group healthy count is less than 1."
  treat_missing_data        = "breaching"
  alarm_actions             = [] # No actions - used by composite alarm
  ok_actions                = []
  insufficient_data_actions = []
  dimensions = {
    TargetGroup  = var.target_group_green_id
    LoadBalancer = var.lb_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.load_balancer_type}-healthy-count-green"
    }
  )
}

# Composite alarm - triggers only when BOTH blue AND green have no healthy targets
resource "aws_cloudwatch_composite_alarm" "lb_healthy_count_combined" {
  alarm_name        = "${var.app_name}_${var.load_balancer_type}_healthy_count_combined"
  alarm_description = "Triggers when BOTH blue AND green target groups have no healthy targets"

  # AND logic - both alarms must be in ALARM state
  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.lb_healthy_count_blue.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.lb_healthy_count_green.alarm_name})"

  alarm_actions             = [var.chatbot_alert_sns_topic_arn]
  ok_actions                = [var.chatbot_alert_sns_topic_arn]
  insufficient_data_actions = []

  # Explicit dependencies to ensure metric alarms are created first
  depends_on = [
    aws_cloudwatch_metric_alarm.lb_healthy_count_blue,
    aws_cloudwatch_metric_alarm.lb_healthy_count_green
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.load_balancer_type}-healthy-count-combined"
    }
  )
}

# Create a metric filter to detect errors in ECS logs
resource "aws_cloudwatch_log_metric_filter" "ecs_service_log_errors" {
  name           = "${var.app_name}-ecs-service-log-errors"
  pattern        = var.cw_alarm_ecs_log_error_pattern
  log_group_name = var.ecs_cloudwatch_log_group_name

  metric_transformation {
    name          = "${var.app_name}_ecs_service_log_errors"
    namespace     = "${var.app_name}/ECS/LogErrors"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# Create alarm based on the log error metric
resource "aws_cloudwatch_metric_alarm" "ecs_service_log_errors_alarm" {
  alarm_name          = "${var.app_name}-ecs-service-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cw_alarm_log_error_evaluation_periods
  metric_name         = "${var.app_name}_ecs_service_log_errors"
  namespace           = "${var.app_name}/ECS/LogErrors"
  period              = var.cw_alarm_log_error_period
  statistic           = "Sum"
  threshold           = 0 # Any error will trigger the alarm
  alarm_description   = "This alarm monitors for any ERROR messages in the ECS service logs"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  ok_actions          = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.tags, {
    Name = "${var.app_name}-ecs-service-log-errors"
  })
}
