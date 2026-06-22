resource "random_uuid" "s3_bucket_postfix_uuid" {}

locals {
  bucket_name = "${var.app_name}-backend-storage-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name      = local.bucket_name
      ManagedBy = "Terraform"
    }
  )
}

# Optional lifecycle: expire noncurrent versions and abort incomplete multipart
# uploads. Default OFF to preserve prior behavior for existing callers.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-and-abort-mpu"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_days
    }
  }
}

# Block public access. ACLs are always blocked (ownership is BucketOwnerEnforced, so
# ACLs are unused anyway). When public_read is enabled, public *bucket policies* are
# allowed so the policy below can grant anonymous read of web assets (static/media).
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = !var.public_read
  ignore_public_acls      = true
  restrict_public_buckets = !var.public_read
}

# Optional anonymous read of objects (public web assets like static/media). Granted via
# a bucket POLICY (not ACLs — ownership is BucketOwnerEnforced). Only enable on buckets
# that hold exclusively public assets; NEVER stage secrets in a public_read bucket.
data "aws_iam_policy_document" "public_read" {
  count = var.public_read ? 1 : 0
  statement {
    sid       = "PublicReadGetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  count  = var.public_read ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.public_read[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# CORS configuration for frontend to upload/download via pre-signed URLs
resource "aws_s3_bucket_cors_configuration" "this" {
  count  = var.create_cors_configuration ? 1 : 0
  bucket = aws_s3_bucket.this.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "DELETE", "HEAD"]
    allowed_origins = var.allowed_origins
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# IAM policy document for backend to get, put, delete objects (attach to ECS task role, etc.)
data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowBackendS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "this" {
  count       = var.create_access_policy ? 1 : 0
  name        = "${var.app_name}-backend-storage-access"
  description = "Policy for backend to access S3 bucket via pre-signed URLs"
  policy      = data.aws_iam_policy_document.this.json
}
