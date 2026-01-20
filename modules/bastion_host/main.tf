# Security group for bastion host
resource "aws_security_group" "bastion" {
  name        = "${var.app_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH access from specified IP addresses
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-sg"
  })
}

# User data script to install MySQL client
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    mysql_commands = "echo 'MySQL client installation completed'"
  }))

  # Auto-generate unique scheduler tag value for this specific bastion host
  scheduler_tag_value = var.enable_scheduler ? "${var.app_name}-bastion-scheduler" : null
}

# EC2 instance for bastion host
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  user_data_base64 = local.user_data

  # Enable detailed monitoring
  monitoring = false

  # Root block device - override AMI defaults
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-host"
    # Auto-generated unique tag for EventBridge + Lambda scheduler
    "BastionScheduler" = var.enable_scheduler ? local.scheduler_tag_value : "disabled"
  })
}

# IAM role for Lambda function to start/stop EC2 instances
resource "aws_iam_role" "scheduler_lambda_role" {
  count = var.enable_scheduler ? 1 : 0

  name = "${var.app_name}-bastion-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-scheduler-lambda-role"
  })
}

# IAM policy for Lambda to start/stop EC2 instances
resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  count = var.enable_scheduler ? 1 : 0

  name = "${var.app_name}-bastion-scheduler-lambda-policy"
  role = aws_iam_role.scheduler_lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/BastionScheduler" = local.scheduler_tag_value
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda function for EC2 scheduling using terraform-aws-modules
module "scheduler_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "=8.1.2"

  count = var.enable_scheduler ? 1 : 0

  function_name = "${var.app_name}-bastion-scheduler"
  description   = "Lambda function to start/stop bastion host based on schedule"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  # Python source directory
  source_path = "${path.module}/scheduler-lambda-function"

  # Use Docker for consistent Python builds
  build_in_docker = false

  # Create role or use existing role
  create_role = false
  lambda_role = aws_iam_role.scheduler_lambda_role[0].arn

  environment_variables = {
    TAG_KEY   = "BastionScheduler"
    TAG_VALUE = local.scheduler_tag_value
  }

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-scheduler-lambda"
  })
}

# EventBridge rule to start instances (weekdays at 7:00 AM GMT+7)
resource "aws_cloudwatch_event_rule" "start_schedule" {
  count = var.enable_scheduler ? 1 : 0

  name                = "${var.app_name}-bastion-start-schedule"
  description         = "Trigger bastion host start based on schedule: ${var.scheduler_start_cron}"
  schedule_expression = var.scheduler_start_cron

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-start-schedule"
  })
}

# EventBridge rule to stop instances (weekdays at 7:00 PM GMT+7)
resource "aws_cloudwatch_event_rule" "stop_schedule" {
  count = var.enable_scheduler ? 1 : 0

  name                = "${var.app_name}-bastion-stop-schedule"
  description         = "Trigger bastion host stop based on schedule: ${var.scheduler_stop_cron}"
  schedule_expression = var.scheduler_stop_cron

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-stop-schedule"
  })
}

# EventBridge target for start rule
resource "aws_cloudwatch_event_target" "start_target" {
  count = var.enable_scheduler ? 1 : 0

  rule      = aws_cloudwatch_event_rule.start_schedule[0].name
  target_id = "StartBastionTarget"
  arn       = module.scheduler_lambda[0].lambda_function_arn

  input = jsonencode({
    action = "start"
  })
}

# EventBridge target for stop rule  
resource "aws_cloudwatch_event_target" "stop_target" {
  count = var.enable_scheduler ? 1 : 0

  rule      = aws_cloudwatch_event_rule.stop_schedule[0].name
  target_id = "StopBastionTarget"
  arn       = module.scheduler_lambda[0].lambda_function_arn

  input = jsonencode({
    action = "stop"
  })
}

# Lambda permissions for EventBridge to invoke function
resource "aws_lambda_permission" "allow_eventbridge_start" {
  count = var.enable_scheduler ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = module.scheduler_lambda[0].lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_schedule[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  count = var.enable_scheduler ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = module.scheduler_lambda[0].lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_schedule[0].arn
}

# Elastic IP for bastion host
resource "aws_eip" "bastion" {
  count    = var.create_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = merge(var.tags, {
    Name = "${var.app_name}-bastion-eip"
  })

  depends_on = [aws_instance.bastion]
}
