resource "random_uuid" "s3_bucket_postfix_uuid" {}

resource "aws_s3_bucket" "api_assets" {
  bucket = "${var.app_name}-api-assets-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"

  tags = {
    Name = "${var.app_name}-api-assets-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"
  }
}

data "aws_iam_policy_document" "static-assets" {
  statement {
    sid    = "Allow CloudFront"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.origin_access_identity_iam_arn]
    }
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.api_assets.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.api_assets.id
  policy = data.aws_iam_policy_document.static-assets.json
}

resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.api_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = [
      "https://${var.frontend_agent_domain}",
      "https://${var.frontend_jobseeker_domain}",
      "https://${var.api_domain}"
    ]
    max_age_seconds = 0
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.api_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.api_assets.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
