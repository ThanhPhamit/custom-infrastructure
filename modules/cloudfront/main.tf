# CloudFront distribution for ALB
resource "aws_cloudfront_distribution" "main" {

  origin {
    domain_name = var.alb_domain_name
    origin_id   = "ALB-${var.app_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  comment = "CloudFront distribution for ${var.app_name} with CloudFront Function auth"

  # Custom domain aliases (optional)
  aliases = var.custom_domain != "" ? [var.custom_domain] : []

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.app_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Modern approach using cache policies instead of deprecated forwarded_values
    cache_policy_id          = var.cache_policy_id != "" ? var.cache_policy_id : aws_cloudfront_cache_policy.main[0].id
    origin_request_policy_id = var.origin_request_policy_id != "" ? var.origin_request_policy_id : aws_cloudfront_origin_request_policy.main[0].id

    # Optional response headers policy
    response_headers_policy_id = var.response_headers_policy_id != "" ? var.response_headers_policy_id : null

    # Optional CloudFront Function for authentication
    dynamic "function_association" {
      for_each = var.enable_default_auth ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.basic_auth.arn
      }
    }
  }

  # Additional cache behaviors for specific paths (optional)
  dynamic "ordered_cache_behavior" {
    for_each = var.cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      target_origin_id       = "ALB-${var.app_name}"
      compress               = true
      viewer_protocol_policy = "redirect-to-https"

      # Modern approach using cache policies instead of deprecated forwarded_values
      cache_policy_id          = lookup(ordered_cache_behavior.value, "cache_policy_id", "") != "" ? ordered_cache_behavior.value.cache_policy_id : aws_cloudfront_cache_policy.main[0].id
      origin_request_policy_id = lookup(ordered_cache_behavior.value, "origin_request_policy_id", "") != "" ? ordered_cache_behavior.value.origin_request_policy_id : aws_cloudfront_origin_request_policy.main[0].id

      # Optional response headers policy for ordered cache behaviors
      response_headers_policy_id = lookup(ordered_cache_behavior.value, "response_headers_policy_id", "") != "" ? ordered_cache_behavior.value.response_headers_policy_id : null

      # Add function association support for ordered cache behaviors
      dynamic "function_association" {
        for_each = lookup(ordered_cache_behavior.value, "enable_auth", false) ? [1] : []
        content {
          event_type   = "viewer-request"
          function_arn = aws_cloudfront_function.basic_auth.arn
        }
      }
    }
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL Certificate configuration
  viewer_certificate {
    # Use custom domain certificate if provided, otherwise use default
    acm_certificate_arn            = var.custom_domain != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.custom_domain != "" ? "sni-only" : null
    minimum_protocol_version       = var.custom_domain != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.custom_domain == "" ? true : null
  }

  # Price class - controls which edge locations to use
  price_class = var.price_class

  # Logging configuration (optional)
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
    }
  }

  tags = var.tags
}

# CloudFront Function for basic authentication (optional)
resource "aws_cloudfront_function" "basic_auth" {
  name    = "${var.app_name}-cloudfront-auth"
  runtime = "cloudfront-js-1.0"
  comment = "Basic authentication for ${var.app_name}"
  publish = true
  code = templatefile(
    "${path.module}/basic_auth.js",
    {
      authString = base64encode("${var.basic_auth_username}:${var.basic_auth_password}")
    }
  )
}

# CloudFront Cache Policy
resource "aws_cloudfront_cache_policy" "main" {
  count = var.cache_policy_id == "" ? 1 : 0

  name        = "${var.app_name}-cache-policy"
  comment     = "Cache policy for ${var.app_name}"
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl
  min_ttl     = var.min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    query_strings_config {
      query_string_behavior = "all"
    }

    headers_config {
      header_behavior = var.forwarded_headers != null && length(var.forwarded_headers) > 0 ? "whitelist" : "none"
      dynamic "headers" {
        for_each = var.forwarded_headers != null && length(var.forwarded_headers) > 0 ? [1] : []
        content {
          items = var.forwarded_headers
        }
      }
    }

    cookies_config {
      cookie_behavior = "all"
    }
  }
}

# CloudFront Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "main" {
  count = var.origin_request_policy_id == "" ? 1 : 0

  name    = "${var.app_name}-origin-request-policy"
  comment = "Origin request policy for ${var.app_name}"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = var.forwarded_headers != null && length(var.forwarded_headers) > 0 ? "whitelist" : "allViewer"
    dynamic "headers" {
      for_each = var.forwarded_headers != null && length(var.forwarded_headers) > 0 ? [1] : []
      content {
        items = var.forwarded_headers
      }
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# Route53 record for custom domain
resource "aws_route53_record" "cloudfront_domain" {
  count = var.custom_domain != "" && var.route_53_zone_id != "" ? 1 : 0

  zone_id = var.route_53_zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 record for AAAA (IPv6) support
resource "aws_route53_record" "cloudfront_domain_ipv6" {
  count = var.custom_domain != "" && var.route_53_zone_id != "" && var.enable_ipv6 ? 1 : 0

  zone_id = var.route_53_zone_id
  name    = var.custom_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
