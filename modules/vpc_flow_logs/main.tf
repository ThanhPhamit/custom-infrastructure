resource "aws_cloudwatch_log_group" "this" {
  name              = "/vpc/flow-logs/${var.app_name}"
  retention_in_days = var.retention_days
  kms_key_id        = var.log_kms_key_id

  tags = merge(var.tags, { Name = "${var.app_name}-vpc-flow-logs", ManagedBy = "Terraform" })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.app_name}-vpcfl-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = merge(var.tags, { Name = "${var.app_name}-vpc-flow-logs-role", ManagedBy = "Terraform" })
}

data "aws_iam_policy_document" "publish" {
  statement {
    sid       = "WriteFlowLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"] # DescribeLogGroups cannot be resource-scoped
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.app_name}-vpc-flow-logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.publish.json
}

resource "aws_flow_log" "this" {
  vpc_id                   = var.vpc_id
  traffic_type             = var.traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.this.arn
  iam_role_arn             = aws_iam_role.this.arn
  max_aggregation_interval = var.max_aggregation_interval

  tags = merge(var.tags, { Name = "${var.app_name}-vpc-flow-log", ManagedBy = "Terraform" })
}
