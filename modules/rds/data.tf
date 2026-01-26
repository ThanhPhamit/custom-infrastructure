data "aws_iam_policy_document" "rds_s3_integration" {
  count = var.enable_s3_integration ? 1 : 0

  statement {
    sid    = "s3import"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = var.s3_bucket_arns != null ? var.s3_bucket_arns : ["*"]
  }
}
