output "rule_names" {
  description = "Names of the EventBridge rules created."
  value = compact([
    aws_cloudwatch_event_rule.dlm_policy_state.name,
    try(aws_cloudwatch_event_rule.dlm_api_change[0].name, ""),
    try(aws_cloudwatch_event_rule.snapshot_failed[0].name, ""),
  ])
}
