variable "app_name" {
  type = string
}

variable "slack_workspace_id" {
  type = string
}

variable "slack_channel_id" {
  type = string
}

variable "slack_channel_name" {
  type = string
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

# AWS Chatbot allows exactly ONE Slack channel configuration per (Slack channel, AWS account):
# a second one fails with "Slack channel with ID <id> ... has already been configured for AWS
# account <id>". Set this false to get the SNS topic + IAM role without claiming the channel —
# needed whenever two stacks (e.g. two regions during a migration) must publish to one channel,
# or while ownership of a channel is being handed from one stack to another.
variable "create_slack_channel_config" {
  description = "Create the Slack channel configuration. False yields only the SNS topic + IAM role (the channel stays owned by whichever stack has it)."
  type        = bool
  default     = true
}

variable "allow_eventbridge_publish" {
  description = <<-EOT
    Attach an explicit topic policy that lets EventBridge (events.amazonaws.com) publish to this
    topic, for rules that notify Slack directly rather than through a CloudWatch alarm.

    Read this before enabling it. An aws_sns_topic_policy REPLACES the default policy AWS attaches to
    a new topic, and that default is what currently lets CloudWatch alarms publish. The policy
    written here therefore restates account-owner access and grants cloudwatch.amazonaws.com
    explicitly as well -- leaving either out silently kills every alarm notification on this topic,
    which is the exact failure mode an alerting change must never introduce.

    Both service grants are scoped with aws:SourceAccount so another account's EventBridge or
    CloudWatch cannot publish here.
  EOT
  type        = bool
  default     = false
}
