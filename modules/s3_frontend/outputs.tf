output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.frontend.bucket
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (use for cache invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "website_urls" {
  description = "Website URLs (custom domains)"
  value       = [for domain in var.domains : "https://${domain}"]
}

output "domains" {
  description = "List of configured domains"
  value       = var.domains
}

output "basic_auth_secret_arn" {
  description = "Secrets Manager ARN for basic auth credentials (null if basic auth disabled)"
  value       = var.create_cloudfront_function ? aws_secretsmanager_secret.basic_auth[0].arn : null
}
