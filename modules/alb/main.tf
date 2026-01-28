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

  # Allow ICMP (ping) from specified IPs for network troubleshooting
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.restricted_source_ips
  }

  # Allow traffic to port 10443 from within the VPC
  ingress {
    from_port   = 10443
    to_port     = 10443
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidrs
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

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb"
    }
  )
}

resource "aws_lb_listener" "http_prod" {
  port              = "443"
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.alb.arn
  certificate_arn   = var.acm_certificate_arn

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
      Name = "${var.app_name}-alb-http-prod"
    }
  )
}

resource "aws_lb_listener" "http_test" {
  port              = "10443"
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.alb.arn
  certificate_arn   = var.acm_certificate_arn

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
