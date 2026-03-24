# ─────────────────────────────────────────────────────────────────────────────
# Alert Email – Reusable SNS → Lambda → SES gateway
#
# Any AWS service can publish to the SNS topic. Lambda renders a clean HTML
# email (no unsubscribe link) and delivers it via SES.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  function_name = "${var.app_name}-alert-email"
  ses_region    = coalesce(var.ses_region, data.aws_region.current.region)
}

# ─────────────────────────────────────────────────────────────────────────────
# SNS Topic (shared entry-point for all alert producers)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
  tags = merge({ Name = "${var.app_name}-alerts" }, var.tags)
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_topic.json
}

data "aws_iam_policy_document" "sns_topic" {
  # CloudWatch Alarms can publish
  statement {
    sid    = "AllowCloudWatchPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Any IAM principal in the same account can publish
  statement {
    sid    = "AllowAccountPublish"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Lambda Function (SNS → SES email forwarder)
# ─────────────────────────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/.dist/index.zip"
}

resource "aws_lambda_function" "forwarder" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      SENDER_EMAIL     = var.sender_email
      RECIPIENT_EMAILS = jsonencode(var.recipient_emails)
      APP_NAME         = var.app_name
      SES_REGION       = local.ses_region
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = merge({ Name = local.function_name }, var.tags)
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.lambda_log_retention_days
  tags              = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# SNS → Lambda Subscription
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.forwarder.arn
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role for Lambda
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ Name = "${local.function_name}-role" }, var.tags)
}

# SES send permission – scoped to the configured sender address
resource "aws_iam_role_policy" "lambda_ses" {
  name = "${local.function_name}-ses"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
      Condition = {
        StringEquals = {
          "ses:FromAddress" = var.sender_email
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ─────────────────────────────────────────────────────────────────────────────
# SES Email Identity (sender verification)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ses_email_identity" "sender" {
  count = var.create_ses_identity ? 1 : 0
  email = var.sender_email
}
