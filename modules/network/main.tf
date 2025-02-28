terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.app_name
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_ciders)
  cidr_block              = var.public_subnet_ciders[count.index]
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "${var.aws_region}${var.azs_name[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-${var.azs_name[count.index]}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_ciders)
  cidr_block        = var.private_subnet_ciders[count.index]
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${var.aws_region}${var.azs_name[count.index]}"

  tags = {
    Name = "${var.app_name}-private-${var.azs_name[count.index]}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.app_name
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_vpc.vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_ciders)

  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_vpc.vpc.default_route_table_id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.app_name}-private-rtb"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_ciders)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  policy       = <<POLICY
    {
      "Statement": [
        {
          "Action": "*",
          "Effect": "Allow",
          "Resource": "*",
          "Principal": "*"
        }
      ]
    }
    POLICY
}

resource "aws_vpc_endpoint_route_table_association" "private" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
  route_table_id  = aws_route_table.private.id
}
