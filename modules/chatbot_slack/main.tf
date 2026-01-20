locals {
  readonly_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "awscc_chatbot_slack_channel_configuration" "this" {
  configuration_name = "${var.app_name}-${var.slack_channel_name}-slack"
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_channel_id   = var.slack_channel_id
  slack_workspace_id = var.slack_workspace_id
  guardrail_policies = [
    aws_iam_policy.chatbot.arn,
    local.readonly_policy_arn
  ]
  sns_topic_arns = [aws_sns_topic.chatbot.arn]

  tags = [
    for k, v in merge(var.tags, { Name = "${var.app_name}-${var.slack_channel_name}-chatbot-slack" }) :
    {
      key   = k
      value = v
    }
  ]
}

resource "aws_iam_role" "chatbot" {
  name = "${var.app_name}-${var.slack_channel_name}-AWSChatbot-Role"

  assume_role_policy = <<-EOS
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "chatbot.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOS
}

data "aws_iam_policy_document" "chatbot" {
  statement {
    effect = "Deny"
    actions = [
      "iam:*",
      "s3:GetBucketPolicy",
      "ssm:*",
      "sts:*",
      "kms:*",
      "cognito-idp:GetSigningCertificate",
      "ec2:GetPasswordData",
      "ecr:GetAuthorizationToken",
      "gamelift:RequestUploadCredentials",
      "gamelift:GetInstanceAccess",
      "lightsail:DownloadDefaultKeyPair",
      "lightsail:GetInstanceAccessDetails",
      "lightsail:GetKeyPair",
      "lightsail:GetKeyPairs",
      "redshift:GetClusterCredentials",
      "storagegateway:DescribeChapCredentials"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:invokeAsync",
      "lambda:invokeFunction"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "chatbot" {
  name   = "${var.app_name}-${var.slack_channel_name}-chatbot-policy"
  policy = data.aws_iam_policy_document.chatbot.json
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.slack_channel_name}-chatbot-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "chatbot" {
  policy_arn = aws_iam_policy.chatbot.arn
  role       = aws_iam_role.chatbot.name
}

resource "aws_iam_role_policy_attachment" "chatbot_readonly" {
  policy_arn = local.readonly_policy_arn
  role       = aws_iam_role.chatbot.name
}

resource "aws_sns_topic" "chatbot" {
  name = "${var.app_name}-${var.slack_channel_name}-chatbot-sns-topic"
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.slack_channel_name}-chatbot-sns-topic"
    }
  )
}
