terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

################################################################################
# Local Variables
################################################################################

locals {
  # Calculate the number of NAT gateways to create
  nat_gateway_count = var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.azs) : length(var.private_subnets))

  # Determine which AZs to use
  azs = length(var.azs) > 0 ? var.azs : [for az in var.azs_name : "${var.aws_region}${az}"]
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags
  )
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.dhcp_options_tags
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = aws_vpc.this[0].id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = var.create_vpc && var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.igw_tags
  )
}

################################################################################
# Public Subnets
################################################################################

resource "aws_subnet" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = length(local.azs) > 0 ? element(local.azs, count.index) : null
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.public_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.public_subnet_tags
  )
}

################################################################################
# Private Subnets
################################################################################

resource "aws_subnet" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = length(local.azs) > 0 ? element(local.azs, count.index) : null

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.private_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.private_subnet_tags
  )
}

################################################################################
# Database Subnets
################################################################################

resource "aws_subnet" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = length(local.azs) > 0 ? element(local.azs, count.index) : null

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.database_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.database_subnet_tags
  )
}

resource "aws_db_subnet_group" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 && var.create_database_subnet_group ? 1 : 0

  name        = lower(coalesce(var.database_subnet_group_name, var.name))
  description = "Database subnet group for ${var.name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = merge(
    { "Name" = coalesce(var.database_subnet_group_name, var.name) },
    var.tags,
    var.database_subnet_group_tags
  )
}

################################################################################
# Elasticache Subnets
################################################################################

resource "aws_subnet" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 ? length(var.elasticache_subnets) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.elasticache_subnets[count.index]
  availability_zone = length(local.azs) > 0 ? element(local.azs, count.index) : null

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.elasticache_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.elasticache_subnet_tags
  )
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 && var.create_elasticache_subnet_group ? 1 : 0

  name        = coalesce(var.elasticache_subnet_group_name, var.name)
  description = "ElastiCache subnet group for ${var.name}"
  subnet_ids  = aws_subnet.elasticache[*].id

  tags = merge(
    { "Name" = coalesce(var.elasticache_subnet_group_name, var.name) },
    var.tags,
    var.elasticache_subnet_group_tags
  )
}

################################################################################
# Intra Subnets (No Internet Access)
################################################################################

resource "aws_subnet" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? length(var.intra_subnets) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.intra_subnets[count.index]
  availability_zone = length(local.azs) > 0 ? element(local.azs, count.index) : null

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.intra_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.intra_subnet_tags
  )
}

################################################################################
# Public Route Table
################################################################################

resource "aws_route_table" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    { "Name" = "${var.name}-${var.public_subnet_suffix}" },
    var.tags,
    var.public_route_table_tags
  )
}

resource "aws_route" "public_internet_gateway" {
  count = var.create_vpc && var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

################################################################################
# Private Route Tables
# Each AZ gets its own private route table when using one NAT gateway per AZ
################################################################################

resource "aws_route_table" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? local.nat_gateway_count : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-${var.private_subnet_suffix}" : format(
        "${var.name}-${var.private_subnet_suffix}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.private_route_table_tags
  )
}

resource "aws_route_table_association" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(
    aws_route_table.private[*].id,
    var.single_nat_gateway ? 0 : count.index
  )
}

################################################################################
# Database Route Table
################################################################################

resource "aws_route_table" "database" {
  count = var.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    { "Name" = "${var.name}-${var.database_subnet_suffix}" },
    var.tags,
    var.database_route_table_tags
  )
}

resource "aws_route_table_association" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0

  subnet_id = element(aws_subnet.database[*].id, count.index)
  route_table_id = element(
    coalescelist(aws_route_table.database[*].id, aws_route_table.private[*].id),
    var.create_database_subnet_route_table ? 0 : count.index
  )
}

resource "aws_route" "database_internet_gateway" {
  count = var.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 && var.create_database_internet_gateway_route && var.create_igw ? 1 : 0

  route_table_id         = aws_route_table.database[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "database_nat_gateway" {
  count = var.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 && !var.create_database_internet_gateway_route && var.create_database_nat_gateway_route && var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.database[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, 0)

  timeouts {
    create = "5m"
  }
}

################################################################################
# Elasticache Route Table
################################################################################

resource "aws_route_table" "elasticache" {
  count = var.create_vpc && var.create_elasticache_subnet_route_table && length(var.elasticache_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    { "Name" = "${var.name}-${var.elasticache_subnet_suffix}" },
    var.tags,
    var.elasticache_route_table_tags
  )
}

resource "aws_route_table_association" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 ? length(var.elasticache_subnets) : 0

  subnet_id = element(aws_subnet.elasticache[*].id, count.index)
  route_table_id = element(
    coalescelist(
      aws_route_table.elasticache[*].id,
      aws_route_table.private[*].id
    ),
    var.create_elasticache_subnet_route_table ? 0 : count.index
  )
}

resource "aws_route" "elasticache_nat_gateway" {
  count = var.create_vpc && var.create_elasticache_subnet_route_table && var.create_elasticache_nat_gateway_route && var.enable_nat_gateway && length(var.elasticache_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.elasticache[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, 0)

  timeouts {
    create = "5m"
  }
}

################################################################################
# Intra Route Table
################################################################################

resource "aws_route_table" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    { "Name" = "${var.name}-${var.intra_subnet_suffix}" },
    var.tags,
    var.intra_route_table_tags
  )
}

resource "aws_route_table_association" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? length(var.intra_subnets) : 0

  subnet_id      = element(aws_subnet.intra[*].id, count.index)
  route_table_id = element(aws_route_table.intra[*].id, 0)
}

################################################################################
# NAT Gateway
################################################################################

resource "aws_eip" "nat" {
  count = var.create_vpc && var.enable_nat_gateway && !var.reuse_nat_ips ? local.nat_gateway_count : 0

  domain = "vpc"

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.nat_eip_tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(
    var.reuse_nat_ips ? var.external_nat_ip_ids : aws_eip.nat[*].id,
    count.index
  )
  subnet_id = element(
    aws_subnet.public[*].id,
    count.index
  )

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(local.azs, count.index)
      )
    },
    var.tags,
    var.nat_gateway_tags
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  count = var.create_vpc && var.enable_nat_gateway && var.create_private_nat_gateway_route ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

################################################################################
# VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc && var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this[0].id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = merge(
    { "Name" = "${var.name}-s3-endpoint" },
    var.tags,
    var.vpc_endpoint_tags
  )
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = var.create_vpc && var.enable_s3_endpoint && length(var.private_subnets) > 0 ? local.nat_gateway_count : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = element(aws_route_table.private[*].id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = var.create_vpc && var.enable_s3_endpoint && length(var.public_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.public[0].id
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this[0].id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"

  tags = merge(
    { "Name" = "${var.name}-dynamodb-endpoint" },
    var.tags,
    var.vpc_endpoint_tags
  )
}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint && length(var.private_subnets) > 0 ? local.nat_gateway_count : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = element(aws_route_table.private[*].id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint && length(var.public_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = aws_route_table.public[0].id
}

################################################################################
# Default Security Group
################################################################################

resource "aws_default_security_group" "this" {
  count = var.create_vpc && var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self             = lookup(ingress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", 0)
      to_port          = lookup(ingress.value, "to_port", 0)
      protocol         = lookup(ingress.value, "protocol", "-1")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self             = lookup(egress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
      description      = lookup(egress.value, "description", null)
      from_port        = lookup(egress.value, "from_port", 0)
      to_port          = lookup(egress.value, "to_port", 0)
      protocol         = lookup(egress.value, "protocol", "-1")
    }
  }

  tags = merge(
    { "Name" = coalesce(var.default_security_group_name, "${var.name}-default") },
    var.tags,
    var.default_security_group_tags
  )
}

################################################################################
# Default Network ACL
################################################################################

resource "aws_default_network_acl" "this" {
  count = var.create_vpc && var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = aws_vpc.this[0].default_network_acl_id

  # Subnet associations are handled by explicit network ACL association resources
  # subnet_ids = []

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = merge(
    { "Name" = coalesce(var.default_network_acl_name, "${var.name}-default") },
    var.tags,
    var.default_network_acl_tags
  )

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

################################################################################
# Default Route Table
################################################################################

resource "aws_default_route_table" "default" {
  count = var.create_vpc && var.manage_default_route_table ? 1 : 0

  default_route_table_id = aws_vpc.this[0].default_route_table_id
  propagating_vgws       = var.default_route_table_propagating_vgws

  dynamic "route" {
    for_each = var.default_route_table_routes
    content {
      # One of the following destinations must be provided
      cidr_block      = lookup(route.value, "cidr_block", null)
      ipv6_cidr_block = lookup(route.value, "ipv6_cidr_block", null)

      # One of the following targets must be provided
      egress_only_gateway_id    = lookup(route.value, "egress_only_gateway_id", null)
      gateway_id                = lookup(route.value, "gateway_id", null)
      instance_id               = lookup(route.value, "instance_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = merge(
    { "Name" = coalesce(var.default_route_table_name, "${var.name}-default") },
    var.tags,
    var.default_route_table_tags
  )
}
