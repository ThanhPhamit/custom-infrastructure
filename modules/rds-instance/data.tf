data "aws_iam_policy_document" "rds_s3_integration" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]

    effect    = "Allow"
    resources = ["*"]
    sid       = "s3import"
  }
}
