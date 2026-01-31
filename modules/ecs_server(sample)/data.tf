data "aws_caller_identity" "user" {}

# Get VPC information including CIDR block
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ECS Task Execution Role
data "aws_iam_policy_document" "ecs_task_execution_policy_document" {
  # ECR permissions - specific to your repositories
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"] # This must be * for GetAuthorizationToken
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage"
    ]
    resources = [
      "${var.repository_arn}",
      "${var.repository_arn}/*"
    ]
  }

  # CloudWatch Logs permissions - specific to your log groups
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.user.account_id}:log-group:/ecs_server/${var.app_name}",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.user.account_id}:log-group:/ecs_server/${var.app_name}/*"
    ]
  }

  # Secrets Manager permissions for all secrets (created by this module)
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.user.account_id}:secret:${var.app_name}-ecs-*",
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.user.account_id}:secret:${var.app_name}-ses-*",
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.user.account_id}:secret:${var.app_name}-rds-*"
    ]
  }
}

data "aws_iam_policy_document" "ecs_task" {
  # source_policy_documents = [data.aws_iam_policy.ecs_task_role_policy.policy]

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "kms:Decript",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateControlChannel"
    ]
    resources = ["*"]
  }
}
