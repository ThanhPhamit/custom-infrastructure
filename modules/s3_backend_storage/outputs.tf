output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "s3_access_policy_arn" {
  description = "ARN of the IAM policy for backend S3 access (attach to ECS task role)"
  value       = aws_iam_policy.this.arn
}

output "s3_access_policy_json" {
  description = "JSON of the IAM policy document for backend S3 access"
  value       = data.aws_iam_policy_document.this.json
}
