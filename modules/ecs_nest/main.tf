resource "aws_iam_policy" "ecs_task_execution_policy" {
  name   = "${var.app_name}-ecs-task-execution-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy_document.json

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-task-policy"
    }
  )
}

module "ecs_task_execution_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-ecs-task-execution-role"
  identifier = "ecs-tasks.amazonaws.com"

  policy_arns_map = {
    "policy_1" = aws_iam_policy.ecs_task_execution_policy.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_policy" "ecs_task_policy" {
  name   = "${var.app_name}-ecs-task-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.ecs_task.json

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-task-policy"
    }
  )
}

module "ecs_task_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-ecs-task-role"
  identifier = "ecs-tasks.amazonaws.com"
  policy_arns_map = {
    "policy_1" = aws_iam_policy.ecs_task_policy.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-task-role"
    }
  )
}

# SECRETS
resource "random_uuid" "ecs_secrets_uuid" {}
# DB host
resource "aws_secretsmanager_secret" "ecs_db_host" {
  name = "${var.app_name}-ecs-db-host-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-db-host-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "ecs_db_host" {
  secret_id     = aws_secretsmanager_secret.ecs_db_host.id
  secret_string = var.db_host
}

# DB user
resource "aws_secretsmanager_secret" "ecs_db_user" {
  name = "${var.app_name}-ecs-db-user-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-db-user-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "ecs_db_user" {
  secret_id     = aws_secretsmanager_secret.ecs_db_user.id
  secret_string = var.db_user
}

# DB password
resource "aws_secretsmanager_secret" "ecs_db_password" {
  name = "${var.app_name}-ecs-db-password-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-db-password-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "ecs_db_password" {
  secret_id     = aws_secretsmanager_secret.ecs_db_password.id
  secret_string = var.db_password
}

# JWT secret
resource "aws_secretsmanager_secret" "ecs_jwt_secret" {
  name = "${var.app_name}-ecs-jwt-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-jwt-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "jwt_secret" {
  length = 48
}


resource "aws_secretsmanager_secret_version" "ecs_jwt_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# Session secret
resource "aws_secretsmanager_secret" "ecs_session_secret" {
  name = "${var.app_name}-ecs-session-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-session-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "session_secret" {
  length = 48
}


resource "aws_secretsmanager_secret_version" "ecs_session_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_session_secret.id
  secret_string = random_password.session_secret.result
}

# Crypto key secret
resource "aws_secretsmanager_secret" "ecs_crypto_key_secret" {
  name = "${var.app_name}-ecs-crypto-key-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-crypto-key-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "crypto_key_secret" {
  length = 50
}

resource "aws_secretsmanager_secret_version" "ecs_crypto_key_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_crypto_key_secret.id
  secret_string = random_password.crypto_key_secret.result
}

# Crypto IV secret
resource "aws_secretsmanager_secret" "ecs_crypto_iv_secret" {
  name = "${var.app_name}-ecs-crypto-iv-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-crypto-iv-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "crypto_iv_secret" {
  length = 16
}

resource "aws_secretsmanager_secret_version" "ecs_crypto_iv_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_crypto_iv_secret.id
  secret_string = random_password.crypto_iv_secret.result
}

# Crypto salt secret
resource "aws_secretsmanager_secret" "ecs_crypto_salt_secret" {
  name = "${var.app_name}-ecs-crypto-salt-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-crypto-salt-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "crypto_salt_secret" {
  length = 16
}

resource "aws_secretsmanager_secret_version" "ecs_crypto_salt_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_crypto_salt_secret.id
  secret_string = random_password.crypto_salt_secret.result
}

# Refresh token secret
resource "aws_secretsmanager_secret" "ecs_refresh_token_secret" {
  name = "${var.app_name}-ecs-refresh-token-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecs-refresh-token-secret-${substr(random_uuid.ecs_secrets_uuid.result, 0, 2)}"
    }
  )
}

resource "random_password" "refresh_token_secret" {
  length = 48
}

resource "aws_secretsmanager_secret_version" "ecs_refresh_token_secret" {
  secret_id     = aws_secretsmanager_secret.ecs_refresh_token_secret.id
  secret_string = random_password.refresh_token_secret.result
}

resource "aws_ecs_task_definition" "task_definition" {
  family = "${var.app_name}-server"

  cpu                      = var.task_cpu_size
  memory                   = var.task_memory_size
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = templatefile("${path.module}/container_definitions/server-task-def.json.tpl", {
    container_name    = var.container_names[0]
    container_port    = var.container_port
    repository_url    = var.repository_url
    memory_size       = var.task_memory_size
    app_name          = var.app_name
    aws_region        = var.region
    health_check_path = var.app_health_check_path

    # Environment variables
    db_host_secret_arn     = aws_secretsmanager_secret.ecs_db_host.arn
    db_port                = var.db_port
    db_user_secret_arn     = aws_secretsmanager_secret.ecs_db_user.arn
    db_password_secret_arn = aws_secretsmanager_secret.ecs_db_password.arn
    db_name                = var.db_name
    db_schema              = var.db_schema
    db_timezone            = var.db_timezone

    white_list = var.white_list

    jwt_algorithm  = var.jwt_algorithm
    jwt_secret_arn = aws_secretsmanager_secret.ecs_jwt_secret.arn
    jwt_expires_in = var.jwt_expires_in

    refresh_token_secret_arn = aws_secretsmanager_secret.ecs_refresh_token_secret.arn
    refresh_token_expires_in = var.refresh_token_expires_in

    session_secret_arn = aws_secretsmanager_secret.ecs_session_secret.arn

    crypto_key_secret_arn  = aws_secretsmanager_secret.ecs_crypto_key_secret.arn
    crypto_iv_secret_arn   = aws_secretsmanager_secret.ecs_crypto_iv_secret.arn
    crypto_salt_secret_arn = aws_secretsmanager_secret.ecs_crypto_salt_secret.arn
    crypto_algorithm       = var.crypto_algorithm

    redis_url = var.redis_url

    http_timeout       = var.http_timeout
    http_max_redirects = var.http_max_redirects


    wcs_robot_api_url        = var.wcs_robot_api_url
    wcs_max_robot_call_queue = var.wcs_max_robot_call_queue

    queue_host = var.queue_host
    queue_port = var.queue_port

    wcs_robot_ids = var.wcs_robot_ids
    }
  )
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
  task_role_arn      = module.ecs_task_role.iam_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-server-task-definition"
    }
  )
}

resource "aws_cloudwatch_log_group" "log" {
  count = length(var.container_names)
  name  = "/ecs_server/${var.app_name}/${var.container_names[count.index]}"
  tags = merge(
    var.tags,
    {
      Name = "/ecs_server/${var.app_name}/${var.container_names[count.index]}"
    }
  )
}

resource "random_uuid" "target_group_uuid" {}

resource "aws_lb_target_group" "target_group_blue" {
  name   = "${substr(var.app_name, 0, 18)}-server-blue-${substr(random_uuid.target_group_uuid.result, 0, 2)}"
  vpc_id = data.aws_vpc.selected.id

  port        = var.container_port
  protocol    = var.load_balancer_type == "nlb" ? "TCP" : "HTTP"
  target_type = "ip"

  health_check {
    port                = var.container_port
    timeout             = var.load_balancer_type == "nlb" ? 6 : 15
    protocol            = var.load_balancer_type == "nlb" ? "HTTP" : "HTTP" # Use HTTP health check even for NLB
    path                = var.load_balancer_type == "nlb" ? var.app_health_check_path : var.app_health_check_path
    matcher             = var.load_balancer_type == "nlb" ? "200" : null
    healthy_threshold   = var.load_balancer_type == "nlb" ? 3 : 2
    unhealthy_threshold = var.load_balancer_type == "nlb" ? 3 : 2
    interval            = var.load_balancer_type == "nlb" ? 30 : 30
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = merge(
    var.tags,
    {
      Name = "${substr(var.app_name, 0, 18)}-server-blue-${substr(random_uuid.target_group_uuid.result, 0, 2)}"
    }
  )
}

resource "aws_lb_target_group" "target_group_green" {
  name   = "${substr(var.app_name, 0, 18)}-server-green-${substr(random_uuid.target_group_uuid.result, 0, 2)}"
  vpc_id = data.aws_vpc.selected.id

  port        = var.container_port
  protocol    = var.load_balancer_type == "nlb" ? "TCP" : "HTTP"
  target_type = "ip"

  health_check {
    port                = var.container_port
    timeout             = var.load_balancer_type == "nlb" ? 6 : 15
    protocol            = var.load_balancer_type == "nlb" ? "HTTP" : "HTTP" # Use HTTP health check even for NLB
    path                = var.load_balancer_type == "nlb" ? var.app_health_check_path : var.app_health_check_path
    matcher             = var.load_balancer_type == "nlb" ? "200" : null
    healthy_threshold   = var.load_balancer_type == "nlb" ? 3 : 2
    unhealthy_threshold = var.load_balancer_type == "nlb" ? 3 : 2
    interval            = var.load_balancer_type == "nlb" ? 30 : 30
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${substr(var.app_name, 0, 18)}-server-green-${substr(random_uuid.target_group_uuid.result, 0, 2)}"
    }
  )
}

# ALB listener rules (path-based routing)
resource "aws_lb_listener_rule" "http_rule" {
  count        = var.load_balancer_type == "alb" ? 1 : 0
  listener_arn = var.http_prod_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.id
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  lifecycle {
    ignore_changes = [
      action,
    ]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-server-http-rule"
    }
  )
}

resource "aws_lb_listener_rule" "http_test_rule" {
  count        = var.load_balancer_type == "alb" ? 1 : 0
  listener_arn = var.http_test_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_green.id
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  lifecycle {
    ignore_changes = [
      action,
    ]
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-server-http-test-rule"
    }
  )
}

# For NLB, we create the listeners directly since NLB module doesn't create them
# TCP listener for HTTP (port 80)
resource "aws_lb_listener" "nlb_http" {
  count             = var.load_balancer_type == "nlb" ? 1 : 0
  port              = "80"
  protocol          = "TCP"
  load_balancer_arn = var.nlb_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tcp-http"
    }
  )

  lifecycle {
    ignore_changes = [
      default_action,
    ]
  }
}

resource "aws_lb_listener" "nlb_prod" {
  count             = var.load_balancer_type == "nlb" ? 1 : 0
  port              = "443" # Standard HTTPS port
  protocol          = "TLS"
  load_balancer_arn = var.nlb_arn
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tls-prod"
    }
  )

  lifecycle {
    ignore_changes = [
      default_action,
    ]
  }
}

# NLB test listener on different port
resource "aws_lb_listener" "nlb_test" {
  count             = var.load_balancer_type == "nlb" ? 1 : 0
  port              = "10443" # Standard test port
  protocol          = "TLS"
  load_balancer_arn = var.nlb_arn
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_green.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tcp-test"
    }
  )

  lifecycle {
    ignore_changes = [
      default_action,
    ]
  }
}

resource "aws_security_group" "ecs_security_group" {
  name   = "${var.app_name}-ecs"
  vpc_id = data.aws_vpc.selected.id

  revoke_rules_on_delete = true

  ingress {
    description     = "Allow inbound traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
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
      Name = "${var.app_name}-ecs"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Add security group rule to allow ECS to access ElastiCache
resource "aws_security_group_rule" "elasticache_allow_ecs" {
  type                     = "ingress"
  from_port                = var.elasticache_primary_endpoint_port
  to_port                  = var.elasticache_primary_endpoint_port
  protocol                 = "tcp"
  security_group_id        = var.elasticache_security_group_id
  source_security_group_id = aws_security_group.ecs_security_group.id
  description              = "Allow access from ECS tasks to ElastiCache"
}


resource "aws_ecs_service" "ecs_service" {
  name                   = "${var.app_name}-server-service"
  launch_type            = "FARGATE"
  desired_count          = var.desired_task_count
  cluster                = var.cluster_name
  task_definition        = aws_ecs_task_definition.task_definition.arn
  enable_execute_command = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_security_group.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group_blue.arn
    container_name   = var.container_names[0]
    container_port   = var.container_port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # For NLB, ensure listeners are created before the service
  depends_on = [
    aws_lb_listener.nlb_prod,
    aws_lb_listener.nlb_test
  ]

  lifecycle {
    ignore_changes = [
      load_balancer,
      task_definition
    ]
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-server-service"
    }
  )
}
