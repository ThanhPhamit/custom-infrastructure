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
