resource "aws_security_group" "security_group" {
  name   = "${var.app_name}-alb"
  vpc_id = var.vpc_id

  # Allow traffic to port 443 from specified IPs
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.restricted_source_ips
  }

  # Allow traffic to port 80 from specified IPs for redirect
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.restricted_source_ips
  }

  # Allow ICMP (ping) from specified IPs — test path only
  dynamic "ingress" {
    for_each = var.enable_test_listener ? [1] : []
    content {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = var.restricted_source_ips
    }
  }

  # Allow traffic to port 10443 from within the VPC — test listener only
  dynamic "ingress" {
    for_each = var.enable_test_listener ? [1] : []
    content {
      from_port   = 10443
      to_port     = 10443
      protocol    = "tcp"
      cidr_blocks = local.vpc_cidrs
    }
  }

  # Allow traffic from CloudFront prefix list if provided
  dynamic "ingress" {
    for_each = var.allow_cloudfront_prefix_list ? [1] : []
    content {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront[0].id]
      description     = "Allow CloudFront managed prefix list"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "alb" {
  name               = "${var.app_name}-alb"
  load_balancer_type = "application"

  security_groups = [aws_security_group.security_group.id]
  subnets         = var.subnet_ids
  internal        = var.alb_internal

  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb"
    }
  )
}

# Origin mTLS trust store (created only when mTLS=verify and no existing trust store was passed).
resource "aws_lb_trust_store" "this" {
  count = local.create_trust_store ? 1 : 0

  name_prefix                              = substr("${var.app_name}-ts-", 0, 26)
  ca_certificates_bundle_s3_bucket         = var.mutual_auth_ca_bundle_s3_bucket
  ca_certificates_bundle_s3_key            = var.mutual_auth_ca_bundle_s3_key
  ca_certificates_bundle_s3_object_version = var.mutual_auth_ca_bundle_s3_object_version != "" ? var.mutual_auth_ca_bundle_s3_object_version : null

  tags = merge(var.tags, { Name = "${var.app_name}-alb-trust-store" })

  lifecycle {
    precondition {
      condition     = var.mutual_auth_ca_bundle_s3_bucket != "" && var.mutual_auth_ca_bundle_s3_key != ""
      error_message = "enable_mutual_auth (verify) with no mutual_auth_trust_store_arn requires mutual_auth_ca_bundle_s3_bucket and mutual_auth_ca_bundle_s3_key."
    }
  }
}

resource "aws_lb_listener" "http_prod" {
  port              = "443"
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.alb.arn
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = var.ssl_policy

  # Origin mTLS (optional). When enabled, the :443 listener verifies the client certificate the caller
  # (e.g. CloudFront via origin mTLS) presents, against the trust store — a handshake without a cert
  # chaining to the trusted CA is rejected before any HTTP. MANDATORY when this ALB is a CloudFront
  # origin (prefix list / shared-secret header alone are NOT sufficient access control).
  dynamic "mutual_authentication" {
    for_each = var.enable_mutual_auth ? [1] : []
    content {
      mode                             = var.mutual_auth_mode
      trust_store_arn                  = local.mutual_auth_trust_store
      ignore_client_certificate_expiry = var.mutual_auth_mode == "verify" ? var.mutual_auth_ignore_client_certificate_expiry : null
    }
  }

  # Forward to a target group when one is supplied; otherwise return the default fixed "ok" response
  # (the ECS/CodeDeploy pattern, where target groups + listener rules are managed out-of-band).
  default_action {
    type             = local.prod_forward ? "forward" : "fixed-response"
    target_group_arn = local.prod_forward ? var.forward_target_group_arn : null

    dynamic "fixed_response" {
      for_each = local.prod_forward ? [] : [1]
      content {
        content_type = "text/plain"
        status_code  = "200"
        message_body = "ok"
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb-http-prod"
    }
  )
}

resource "aws_lb_listener" "http_test" {
  count             = var.enable_test_listener ? 1 : 0
  port              = "10443"
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.alb.arn
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "ok"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb-http-test"
    }
  )
}

resource "aws_lb_listener" "http_redirect" {
  port              = "80"
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.alb.arn

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb-http-redirect"
    }
  )
}

resource "aws_route53_record" "app_domain_dns_record" {
  count   = var.create_route53_record ? 1 : 0
  name    = var.alb_domain
  type    = "A"
  zone_id = var.route_53_zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
  }

  lifecycle {
    precondition {
      condition     = var.route_53_zone_id != null && var.alb_domain != null
      error_message = "When create_route53_record is true, both route_53_zone_id and alb_domain must be provided."
    }
  }
}

# WAFv2 Web ACL association (REGIONAL scope)
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.web_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = var.web_acl_arn
}
