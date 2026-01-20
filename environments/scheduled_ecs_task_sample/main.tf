# ========================================
# Remark AI Tool - Scheduled ECS Task
# ========================================

# Random UUID for unique secret name
resource "random_uuid" "ecs_secrets_uuid" {}

# AWS Secrets Manager - Database Password
resource "aws_secretsmanager_secret" "ecs_db_password" {
  name        = "${local.app_name}-db-password-${substr(random_uuid.ecs_secrets_uuid.result, 0, 8)}"
  description = "Database password for ${local.app_name} ECS task"

  tags = merge(
    local.tags,
    {
      Name = "${local.app_name}-db-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "ecs_db_password" {
  secret_id     = aws_secretsmanager_secret.ecs_db_password.id
  secret_string = var.remark_ai_tool_db_password
}

# IAM Policy for ECS Task to Access Secrets Manager
resource "aws_iam_policy" "ecs_task_secrets_access" {
  name        = "${local.app_name}-secrets-access"
  description = "Allow ECS task to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.ecs_db_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for ECS Task to Access AWS Bedrock
resource "aws_iam_policy" "ecs_task_bedrock_access" {
  name        = "${local.app_name}-bedrock-access"
  description = "Allow ECS task to invoke AWS Bedrock models and inference profiles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockModelAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:*::foundation-model/anthropic.claude-*"
      },
      {
        Sid    = "BedrockInferenceProfileAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::inference-profile/global.anthropic.claude-*",
          "arn:aws:bedrock:*:${data.aws_caller_identity.user.account_id}:inference-profile/*"
        ]
      }
    ]
  })

  tags = local.tags
}

# ECR Repository for Remark AI Tool
module "remark_ai_tool_ecr" {
  source = "../../scheduled_ecs_task_modules/ecr_private_registry"

  repository_name = local.app_name
  tags            = local.tags
}

# Security Group for ECS Task
resource "aws_security_group" "remark_ai_tool_vpc_endpoint" {
  name        = "${local.app_name}-ecs-task-sg"
  description = "Security group for ${local.app_name} ECS task to access VPC endpoints and on-premise database"
  vpc_id      = var.vpc_id

  # Allow HTTPS traffic to VPC endpoints (ECR, Secrets Manager, CloudWatch Logs)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic to VPC endpoints"
  }

  # Allow traffic to on-premise MSSQL database via S2S VPN
  egress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/24"] # On-premise network range
    description = "Allow MSSQL traffic to on-premise database via VPN"
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.app_name}-ecs-task-sg"
    }
  )
}

# ECS Scheduled Task for Remark AI Tool
module "remark_ai_tool_ecs" {
  source = "../../scheduled_ecs_task_modules/ecs_scheduled_task"

  app_name     = local.app_name
  cluster_name = local.app_name

  # Container Configuration
  ecr_image_uri  = "${module.remark_ai_tool_ecr.repository_url}:latest"
  container_name = "${local.app_name}-container"
  task_cpu       = var.remark_ai_tool_task_cpu
  task_memory    = var.remark_ai_tool_task_memory

  # Environment Variables (non-sensitive)
  container_environment = [
    for key, value in var.remark_ai_tool_environment_vars : {
      name  = key
      value = value
    }
  ]

  # Secrets (sensitive values from Secrets Manager)
  container_secrets = [
    {
      name      = "DATABASE_PASSWORD"
      valueFrom = aws_secretsmanager_secret.ecs_db_password.arn
    }
  ]

  # CloudWatch Logs
  log_retention_days = 30

  # IAM Permissions - Task Execution Role (for pulling images, reading secrets, writing logs)
  task_execution_role_policy_arns = [
    aws_iam_policy.ecs_task_secrets_access.arn
  ]

  # IAM Permissions - Task Role (for application runtime permissions)
  task_role_policy_arns = [
    aws_iam_policy.ecs_task_bedrock_access.arn
  ]

  tags = local.tags

  depends_on = [module.remark_ai_tool_ecr]
}

# EventBridge Scheduler for Remark AI Tool
module "remark_ai_tool_scheduler" {
  source = "../../scheduled_ecs_task_modules/scheduled_task_eventbridge"

  app_name            = local.app_name
  schedule_expression = var.remark_ai_tool_schedule
  rule_description    = "Trigger Remark AI Tool every configured interval"
  enable_rule         = var.remark_ai_tool_enabled

  # ECS Target Configuration
  target_type             = "ecs"
  ecs_cluster_arn         = module.remark_ai_tool_ecs.cluster_arn
  ecs_task_definition_arn = module.remark_ai_tool_ecs.task_definition_arn
  ecs_task_count          = 1
  ecs_subnet_ids          = var.subnet_ids
  ecs_security_group_ids  = [aws_security_group.remark_ai_tool_vpc_endpoint.id]
  ecs_assign_public_ip    = false # Use VPC with S2S VPN to access on-premise DB
  ecs_launch_type         = "FARGATE"

  tags = local.tags

  depends_on = [module.remark_ai_tool_ecs]
}


# OIDC identity provider for GitHub Actions
module "aws_oidc_with_github_actions" {
  source = "../../scheduled_ecs_task_modules/aws_oidc_with_github_actions"

  create_oidc_provider = false
  app_name             = local.app_name
  thumbprint_list      = var.thumbprint_list
  github_org           = "liongarden"      # GitHub organization name
  github_repositories  = ["welfan-remark"] # List of GitHub repository names

  passrole_target_role_arns = [
    module.remark_ai_tool_ecs.task_role_arn,
    module.remark_ai_tool_ecs.task_execution_role_arn,
  ]

  tags = local.tags
}


module "chatbot_slack_alert" {
  source = "../../scheduled_ecs_task_modules/chatbot_slack"

  app_name           = local.app_name
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_alert_channel_id
  slack_channel_name = "system-alert"
  tags               = local.tags

  providers = {
    aws   = aws
    awscc = awscc
  }
}

# CloudWatch Alarms for ECS Scheduled Task
module "remark_ai_tool_ecs_alarms" {
  source = "../../scheduled_ecs_task_modules/cloudwatch_alarm_ecs_scheduled_task"

  app_name                    = local.app_name
  cluster_name                = module.remark_ai_tool_ecs.cluster_name
  log_group_name              = module.remark_ai_tool_ecs.log_group_name
  chatbot_alert_sns_topic_arn = module.chatbot_slack_alert.chatbot_sns_topic_arn

  # Task Failure Monitoring - detects ERROR/Exception in logs (not normal exits)
  enable_task_failure_monitoring = true
  task_failure_log_pattern       = "?ERROR ?CRITICAL ?Exception ?Traceback ?\"❌\""

  # Customize thresholds
  cpu_high_threshold    = 80
  memory_high_threshold = 80

  # Enable log error monitoring (additional error detection)
  enable_log_error_monitoring = true
  log_error_pattern           = "?ERROR ?CRITICAL ?Exception ?Traceback ?\"❌\""

  tags = local.tags

  depends_on = [module.remark_ai_tool_ecs, module.chatbot_slack_alert]
}

# CloudWatch Alarms for EventBridge Scheduler
module "remark_ai_tool_eventbridge_alarms" {
  source = "../../scheduled_ecs_task_modules/cloudwatch_alarm_eventbridge"

  app_name                    = local.app_name
  rule_name                   = module.remark_ai_tool_scheduler.rule_name
  chatbot_alert_sns_topic_arn = module.chatbot_slack_alert.chatbot_sns_topic_arn

  # Enable invocations monitoring (heartbeat) - matches the hourly schedule
  enable_invocations_monitoring = true
  invocations_low_period        = 7200 # 2 hours (2x the schedule interval for safety)
  invocations_low_threshold     = 1

  # DLQ monitoring disabled (no DLQ configured)
  enable_dlq_monitoring = false

  tags = local.tags

  depends_on = [module.remark_ai_tool_scheduler, module.chatbot_slack_alert]
}
