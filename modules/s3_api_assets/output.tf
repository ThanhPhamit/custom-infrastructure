output "bucket_name" {
  value = aws_s3_bucket.api_assets.bucket
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.api_assets.bucket_regional_domain_name
}

output "bucket_id" {
  value = aws_s3_bucket.api_assets.id
}
