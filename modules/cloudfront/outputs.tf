output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "custom_domain" {
  description = "Custom domain name for the CloudFront distribution"
  value       = var.custom_domain != "" ? var.custom_domain : null
}

output "cloudfront_status" {
  description = "Status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.status
}

output "cloudfront_function_arn" {
  description = "ARN of the CloudFront Function (null unless basic auth is enabled)"
  value       = one(aws_cloudfront_function.basic_auth[*].arn)
}

output "vpc_origin_id" {
  description = "ID of the CloudFront VPC origin (null unless enable_vpc_origin = true)"
  value       = one(aws_cloudfront_vpc_origin.main[*].id)
}

output "access_urls" {
  description = "Available access URLs"
  value = {
    alb_direct    = var.alb_domain_name
    cloudfront    = aws_cloudfront_distribution.main.domain_name
    custom_domain = var.custom_domain != "" ? var.custom_domain : null
  }
}
