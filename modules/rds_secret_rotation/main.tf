locals {
  rotation_lambda_name    = "${var.app_name}-rds-rotation"
  secretsmanager_endpoint = "https://secretsmanager.${var.region}.${data.aws_partition.current.dns_suffix}"
  use_schedule_expression = var.rotation_schedule_expression != null && trimspace(var.rotation_schedule_expression) != ""
}

data "aws_partition" "current" {}

resource "aws_security_group" "rotation_lambda" {
  name_prefix = "${var.app_name}-rds-rotation-"
  description = "Security group for Secrets Manager RDS rotation lambda"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-rds-rotation-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_rotation_lambda" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.rotation_lambda.id
  description              = "Allow RDS password rotation lambda"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "postgres_single_user_rotation" {
  name           = "${var.app_name}-rds-rotation-stack"
  application_id = "arn:${data.aws_partition.current.partition}:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    functionName        = local.rotation_lambda_name
    endpoint            = local.secretsmanager_endpoint
    vpcSubnetIds        = join(",", var.subnet_ids)
    vpcSecurityGroupIds = aws_security_group.rotation_lambda.id
  }

  tags = var.tags
}

data "aws_lambda_function" "rotation" {
  function_name = local.rotation_lambda_name

  depends_on = [aws_serverlessapplicationrepository_cloudformation_stack.postgres_single_user_rotation]
}

resource "aws_lambda_permission" "allow_secrets_manager" {
  statement_id  = "AllowSecretsManagerInvokeRotationLambda"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = var.secret_arn
}

resource "aws_secretsmanager_secret_rotation" "this" {
  secret_id           = var.secret_arn
  rotation_lambda_arn = data.aws_lambda_function.rotation.arn
  rotate_immediately  = var.rotate_immediately

  rotation_rules {
    automatically_after_days = local.use_schedule_expression ? null : var.rotation_interval_days
    schedule_expression      = local.use_schedule_expression ? trimspace(var.rotation_schedule_expression) : null
  }

  depends_on = [aws_lambda_permission.allow_secrets_manager]
}
