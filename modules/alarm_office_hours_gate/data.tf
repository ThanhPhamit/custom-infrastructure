data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  state = var.enabled ? "ENABLED" : "DISABLED"

  # Alarm ARNs are built rather than taken as input, so the caller passes the plain names the
  # CloudWatch APIs actually want while the IAM policy still scopes to exactly those alarms.
  alarm_arns = [
    for n in var.alarm_names :
    "arn:aws:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:${n}"
  ]

  # Alarm names conventionally already start with the same app_name prefix, so a naive
  # "${app_name}-alarm-reset-${alarm}" repeats it and blows the 64-char schedule-name limit.
  # Strip the duplicate prefix; the length is then asserted per schedule rather than truncated,
  # because truncation silently collapses two long alarm names into one schedule.
  reset_names = {
    for n in var.alarm_names :
    n => format("%s-alarm-reset-%s", var.app_name, trimprefix(n, "${var.app_name}-"))
  }
}
