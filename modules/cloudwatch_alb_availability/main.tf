# =============================================================================
# No healthy target behind the ALB.
#
# Measured on a live single-instance ALB stack, 2026-08-26: while the instance was stopped the ALB published NO
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
