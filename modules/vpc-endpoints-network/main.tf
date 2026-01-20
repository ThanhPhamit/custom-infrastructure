resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.app_name}-vpc-endpoints"
  description = "Security group for VPC endpoints to allow ECS tasks to access ECR and CloudWatch Logs"
  vpc_id      = data.aws_vpc.this.id

  # Allow traffic from ECS security groups
  ingress {
    description     = "Allow inbound traffic from ECS tasks"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = var.allowed_security_group_ids
  }

  # Allow traffic from VPN clients
  dynamic "ingress" {
    for_each = length(var.vpn_client_cidr_blocks) > 0 ? [1] : []
    content {
      description = "Allow inbound traffic from VPN clients"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = var.vpn_client_cidr_blocks
    }
  }

  egress = []

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-vpc-endpoints"
    }
  )
}

##############################
# VPC Endpoint (ecr.dkr)
##############################
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecr-dkr"
    }
  )
}

##############################
# VPC Endpoint (ecr.api)
##############################
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ecr-api"
    }
  )
}

##############################
# VPC Endpoint (s3)
##############################
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = data.aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.route_table_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-s3-endpoint"
    }
  )
}

##############################
# VPC Endpoint (CloudWatch Logs)
##############################
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-cloudwatch-logs"
    }
  )
}


##############################
# VPC Endpoint (Secrets Manager)
##############################
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(var.tags, {
    Name = "${var.app_name}-secretsmanager"
  })
}

##############################
# VPC Endpoint (SSM) - Required for ECS Exec
##############################
resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_ecs_exec_endpoints ? 1 : 0

  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ssm"
    }
  )
}

##############################
# VPC Endpoint (SSM Messages) - Required for ECS Exec
##############################
resource "aws_vpc_endpoint" "ssmmessages" {
  count = var.enable_ecs_exec_endpoints ? 1 : 0

  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ssmmessages"
    }
  )
}

##############################
# VPC Endpoint (EC2 Messages) - Required for ECS Exec
##############################
resource "aws_vpc_endpoint" "ec2messages" {
  count = var.enable_ecs_exec_endpoints ? 1 : 0

  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ec2messages"
    }
  )
}

##############################
# VPC Endpoint (Bedrock Runtime)
##############################
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = data.aws_subnet.selected[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-bedrock-runtime"
    }
  )
}
