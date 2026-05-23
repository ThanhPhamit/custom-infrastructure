locals {
  # Resolve the effective routing mode: explicit `routing_mode` wins; fall
  # back to the legacy boolean for callers that haven't migrated yet.
  effective_routing_mode = (
    var.routing_mode != null
    ? var.routing_mode
    : (var.enable_spa_router ? "spa" : "none")
  )
  routing_function_enabled = local.effective_routing_mode != "none"
}

resource "random_uuid" "s3_bucket_postfix_uuid" {}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.app_name}-frontend-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"

  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-frontend-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"
    }
  )
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "cleanup-object-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.app_name}-cf-oac-for-frontend-s3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_secretsmanager_secret" "basic_auth" {
  count       = var.create_cloudfront_function ? 1 : 0
  name_prefix = "${var.app_name}-CDN-basic-auth"
  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-CDN-basic-auth"
    }
  )
}

resource "aws_secretsmanager_secret_version" "basic_auth_version" {
  count     = var.create_cloudfront_function ? 1 : 0
  secret_id = aws_secretsmanager_secret.basic_auth[count.index].id
  secret_string = jsonencode({
    username = var.app_name
    password = var.basic_auth_password
  })

  depends_on = [aws_secretsmanager_secret.basic_auth]
}

resource "aws_cloudfront_function" "basic_auth" {
  count   = var.create_cloudfront_function && local.effective_routing_mode == "none" ? 1 : 0
  name    = "${var.app_name}-basic-auth"
  runtime = "cloudfront-js-2.0"
  comment = "Basic Auth"
  publish = true
  code = templatefile(
    "${path.module}/basic_auth.js",
    {
      authString = base64encode("${jsondecode(aws_secretsmanager_secret_version.basic_auth_version[count.index].secret_string).username}:${jsondecode(aws_secretsmanager_secret_version.basic_auth_version[count.index].secret_string).password}")
    }
  )
  depends_on = [aws_secretsmanager_secret_version.basic_auth_version]
}

# Router CloudFront Function. One function regardless of bundler: SPA (single
# index.html, client-side router) OR Next.js static export (per-route HTML).
# The chosen JS file rewrites incoming URIs to the matching S3 object key.
#
# Basic Auth is currently only supported in "spa" mode (existing
# spa_router_with_auth.js). Wire a `nextjs_router_with_auth.js` if you ever
# need to put a Next.js export behind basic auth.
resource "aws_cloudfront_function" "spa_router" {
  count   = local.routing_function_enabled ? 1 : 0
  name    = "${var.app_name}-${local.effective_routing_mode}-router"
  runtime = "cloudfront-js-2.0"
  comment = "${local.effective_routing_mode} URI rewriter"
  publish = true

  code = (
    local.effective_routing_mode == "nextjs"
    ? (
      var.canonical_domain != null
      ? templatefile(
        "${path.module}/nextjs_router_with_canonical_redirect.js",
        { canonical_domain = var.canonical_domain }
      )
      : file("${path.module}/nextjs_router.js")
    )
    : (
      var.create_cloudfront_function
      ? templatefile(
        "${path.module}/spa_router_with_auth.js",
        {
          authString = base64encode("${jsondecode(aws_secretsmanager_secret_version.basic_auth_version[0].secret_string).username}:${jsondecode(aws_secretsmanager_secret_version.basic_auth_version[0].secret_string).password}")
        }
      )
      : file("${path.module}/spa_router.js")
    )
  )

  depends_on = [aws_secretsmanager_secret_version.basic_auth_version]
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.frontend.id
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # Only attach aliases when the caller provided custom domains. Setting
  # aliases without a matching ACM cert in viewer_certificate is invalid.
  aliases     = length(var.domains) > 0 ? var.domains : null
  enabled     = true
  price_class = var.price_class

  default_root_object = var.default_root_object

  # SPA mode: For React/Vue/Angular apps, accessing paths other than root returns 403
  # from S3, so we redirect to index.html for client-side routing to handle
  dynamic "custom_error_response" {
    for_each = var.spa_mode ? [1] : []
    content {
      error_caching_min_ttl = 0
      error_code            = 403
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.spa_mode ? [1] : []
    content {
      error_caching_min_ttl = 0
      error_code            = 404
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.frontend.id

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    # Router function (SPA or Next.js URI rewrite, plus optional basic auth
    # in the SPA path). Attached whenever a routing mode is in effect.
    dynamic "function_association" {
      for_each = local.routing_function_enabled ? [aws_cloudfront_function.spa_router[0]] : []
      content {
        event_type   = "viewer-request"
        function_arn = function_association.value.arn
      }
    }

    # Standalone basic-auth function for routing_mode = "none" (no rewrite,
    # just gate access to a flat static site).
    dynamic "function_association" {
      for_each = var.create_cloudfront_function && local.effective_routing_mode == "none" ? [aws_cloudfront_function.basic_auth[0]] : []
      content {
        event_type   = "viewer-request"
        function_arn = function_association.value.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  # Custom domain → ACM cert in us-east-1. No custom domain → CloudFront's
  # built-in `*.cloudfront.net` cert. Mixing the two (e.g. aliases set but
  # no ACM ARN) is an API error, so the variable validation enforces both
  # are present together.
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-frontend-cloudfront"
    }
  )
}

data "aws_iam_policy_document" "frontend" {
  statement {
    sid    = "Allow CloudFront"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json
}

# Route53 DNS records — created only when custom domains are in play.
# Skipped entirely when `domains` is empty (default-CloudFront-URL mode).
resource "aws_route53_record" "app_domain_dns_record" {
  for_each = var.route_53_zone_id == null ? toset([]) : toset(var.domains)

  name    = each.value
  type    = "A"
  zone_id = var.route_53_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
  }
}
