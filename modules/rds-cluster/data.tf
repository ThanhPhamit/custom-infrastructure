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


data "aws_rds_engine_version" "family" {
  engine   = var.engine
  version  = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  provider = aws.primary
}

data "aws_partition" "current" {}
