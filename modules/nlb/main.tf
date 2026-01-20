resource "aws_security_group" "security_group" {
  name   = "${var.app_name}-nlb"
  vpc_id = var.vpc_id

  # Allow traffic to port 443 from specified IPs (NLB TCP prod)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.restricted_source_ips
  }

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

  # Allow traffic to port 10443 from within the VPC (NLB TCP test)
  ingress {
    from_port   = 10443
    to_port     = 10443
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidrs
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
      Name = "${var.app_name}-nlb"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Default target group for NLB listeners (placeholder)
# This target group will not have any targets and serves as a default action
# ECS modules will create their own target groups and listener rules
resource "aws_lb_target_group" "default_tcp" {
  name     = "${substr(var.app_name, 0, 18)}-nlb-default"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 6
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name = "${substr(var.app_name, 0, 18)}-nlb-default"
    }
  )
}

resource "aws_lb" "nlb" {
  name               = "${var.app_name}-nlb"
  load_balancer_type = "network"

  # NLB can optionally use security groups (requires allocation_id or security_groups)
  security_groups = var.enable_security_groups ? [aws_security_group.security_group.id] : null

  # Use subnet mappings if fixed IPs are configured, otherwise use regular subnets
  subnets = var.use_fixed_ips ? null : var.subnet_ids

  # Subnet mappings for fixed IPs
  dynamic "subnet_mapping" {
    for_each = var.use_fixed_ips ? var.subnet_mappings : []
    content {
      subnet_id            = subnet_mapping.value.subnet_id
      allocation_id        = subnet_mapping.value.allocation_id
      private_ipv4_address = subnet_mapping.value.private_ipv4_address
    }
  }

  internal = var.nlb_internal

  # Enable deletion protection if specified
  enable_deletion_protection = var.enable_deletion_protection

  # Enable cross-zone load balancing if specified
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb"
    }
  )
}

# Listeners will be created by the ECS modules that use this NLB
# This allows proper dependency management and target group association

# Optional TLS listener if TLS termination is needed
resource "aws_lb_listener" "tls_prod" {
  count             = var.enable_tls_termination ? 1 : 0
  port              = "443"
  protocol          = "TLS"
  load_balancer_arn = aws_lb.nlb.arn
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_tcp.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tls-prod"
    }
  )
}

resource "aws_lb_listener" "tls_test" {
  count             = var.enable_tls_termination ? 1 : 0
  port              = "10443"
  protocol          = "TLS"
  load_balancer_arn = aws_lb.nlb.arn
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_tcp.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tls-test"
    }
  )
}

resource "aws_route53_record" "app_domain_dns_record" {
  count   = var.create_route53_record ? 1 : 0
  name    = var.nlb_domain
  type    = "A"
  zone_id = var.route_53_zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
  }
}
