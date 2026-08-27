# =============================================================================
# No healthy target behind the ALB.
#
# Measured on a live single-instance ALB stack, 2026-08-26: while the instance was stopped the ALB
# HealthyHostCount datapoints for the whole outage -- absence, not a zero -- which is why the
# missing-data policy, not the threshold, is what makes this alarm work.
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "no_healthy_host" {
  alarm_name          = "${var.app_name}-alb-no-healthy-host"
  alarm_description   = "No healthy target in ${var.target_group_arn_suffix}: the ALB is serving 503 to every request. Either the target is registered and failing its health check, or no target is registered at all."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  period              = var.period
  evaluation_periods  = var.evaluation_periods

  treat_missing_data = var.treat_missing_data

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = var.enable_ok_actions ? [var.sns_topic_arn] : []

  # Statistic is Maximum on purpose. Average across a period with a flapping target lands between 0
  # and 1 and never crosses "< 1" cleanly; Maximum asks "was there EVER a healthy target in this
  # period", which is the honest reading of an availability alarm.

  # An office-hours gate flips actions_enabled through the CloudWatch API. Without this, Terraform
  # plans it back to true on every apply and re-arms the alarm in the middle of the night.
  actions_enabled = true
  lifecycle {
    ignore_changes = [actions_enabled]
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-alb-no-healthy-host"
    ManagedBy = "Terraform"
  })
}

# =============================================================================
# The target answers, and answers with errors.
#
# HealthyHostCount above cannot see this: a shallow health check keeps the target "healthy" while
# every real request fails. treat_missing_data is notBreaching here -- the exact opposite of the
# availability alarm -- because no data means no traffic, which is not a failure. That also means the
# alarm needs no office-hours gate: an idle night produces no datapoints and no state change.
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  count = var.create_target_5xx_alarm ? 1 : 0

  alarm_name          = "${var.app_name}-alb-target-5xx"
  alarm_description   = "Target in ${var.target_group_arn_suffix} returned more than ${var.target_5xx_threshold} 5xx responses in ${var.target_5xx_period}s. The app is up and passing its health check but failing real requests -- most often a dependency it cannot reach."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.target_5xx_threshold
  period              = var.target_5xx_period
  evaluation_periods  = 1

  # No data = no traffic = not a failure.
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [var.sns_topic_arn]

  # Empty for the same reason as every other alarm in this stack: recovery is visible in the console,
  # and an ok_action here would post twice for every transient blip.
  ok_actions = []

  tags = merge(var.tags, {
    Name      = "${var.app_name}-alb-target-5xx"
    ManagedBy = "Terraform"
  })
}
