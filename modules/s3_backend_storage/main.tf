resource "random_uuid" "s3_bucket_postfix_uuid" {}

locals {
  bucket_name = "${var.app_name}-backend-storage-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

# Block all public access - only access via pre-signed URLs
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for frontend to upload/download via pre-signed URLs
resource "aws_s3_bucket_cors_configuration" "this" {
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
  name        = "${var.app_name}-backend-storage-access"
  description = "Policy for backend to access S3 bucket via pre-signed URLs"
  policy      = data.aws_iam_policy_document.this.json
}
