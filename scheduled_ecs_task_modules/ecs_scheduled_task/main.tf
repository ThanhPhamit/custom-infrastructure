# ========================================
# ECS Cluster
# ========================================

module "ecs_cluster" {
  source = "../ecs_cluster"

  app_name = local.cluster_name
  tags     = var.tags
}

# ========================================
# CloudWatch Log Group
# ========================================

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = local.log_group_name
  })
}

# ========================================
# IAM Roles
# ========================================

# ECS Task Execution Role (used by ECS to pull images and write logs)
module "task_execution_role" {
  source = "../iam_role"

  name        = "${var.app_name}-task-execution-role"
  description = "ECS task execution role for ${var.app_name}"
  identifier  = "ecs-tasks.amazonaws.com"

  policy_arns_map = merge(
    {
      "ecs-task-execution" = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    },
    { for idx, arn in var.task_execution_role_policy_arns : "additional-${idx}" => arn }
  )

  tags = var.tags
}

# ECS Task Role (used by the application itself)
module "task_role" {
  source = "../iam_role"

  name        = "${var.app_name}-task-role"
  description = "ECS task role for ${var.app_name}"
  identifier  = "ecs-tasks.amazonaws.com"

  policy_arns_map = { for idx, arn in var.task_role_policy_arns : "policy-${idx}" => arn }
  inline_policies = var.task_role_inline_policies

  tags = var.tags
}

# ========================================
# ECS Task Definition
# ========================================

resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = module.task_execution_role.iam_role_arn
  task_role_arn            = module.task_role.iam_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.ecr_image_uri
      essential = true

      # Optional command and entrypoint
      command          = var.container_command
      entryPoint       = var.container_entrypoint
      workingDirectory = var.working_directory

      # Environment variables
      environment = var.container_environment

      # Secrets
      secrets = var.container_secrets

      # Log configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = var.app_name
  })
}
