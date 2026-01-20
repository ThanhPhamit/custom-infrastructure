# Network Load Balancer (NLB) Module - Sample Usage

## main.tf

### Example 1: Internal NLB with Fixed IP (Recommended for Internal Services)

```terraform
module "nlb_nest" {
  source = "../../modules/nlb"

  app_name = "${var.environment}-${var.app_name}-nest"
  vpc_id   = data.aws_vpc.this.id

  restricted_source_ips = concat(
    # [for subnet in data.aws_subnet.public_subnets : subnet.cidr_block],
    var.elb_restricted_source_ips
  )

  # Enable fixed IPs and set the desired IP address
  use_fixed_ips = true
  subnet_mappings = [
    {
      subnet_id            = data.aws_subnet.private_subnets[var.nlb_fixed_ip_subnet_id].id
      private_ipv4_address = var.nlb_fixed_ip_address
    }
  ]

  nlb_internal                     = true
  enable_cross_zone_load_balancing = true
  enable_security_groups           = true  # Enable security groups for NLB to control access
  enable_tls_termination           = false # Disable TLS listeners - ECS will create TCP listeners

  route_53_zone_id    = data.aws_route53_zone.this.id
  acm_certificate_arn = module.internal_acm.certificate_arn
  nlb_domain          = var.elb_nest_nlb_domain

  tags = local.tags
}
```

### Example 2: Internal NLB with Dynamic IPs (Multiple Subnets)

```terraform
module "nlb_nuxt" {
  source = "../../modules/nlb"

  app_name = "${var.environment}-${var.app_name}-nuxt"
  vpc_id   = data.aws_vpc.this.id

  restricted_source_ips = var.elb_restricted_source_ips

  # Use multiple subnets with dynamic IPs
  use_fixed_ips = false
  subnet_ids    = [for subnet in data.aws_subnet.private_subnets : subnet.id]

  nlb_internal                     = true
  enable_cross_zone_load_balancing = true
  enable_security_groups           = true
  enable_tls_termination           = false

  route_53_zone_id    = data.aws_route53_zone.this.id
  nlb_domain          = var.elb_nuxt_nlb_domain

  tags = local.tags
}
```

### Example 3: Internet-Facing NLB with Elastic IPs

```terraform
module "nlb_public" {
  source = "../../modules/nlb"

  app_name = "${var.environment}-${var.app_name}-public"
  vpc_id   = data.aws_vpc.this.id

  restricted_source_ips = ["0.0.0.0/0"]  # Allow all internet traffic

  # Use fixed Elastic IPs for public internet-facing NLB
  use_fixed_ips = true
  subnet_mappings = [
    {
      subnet_id     = data.aws_subnet.public_subnets[0].id
      allocation_id = aws_eip.nlb[0].id  # Reference to an Elastic IP
    },
    {
      subnet_id     = data.aws_subnet.public_subnets[1].id
      allocation_id = aws_eip.nlb[1].id
    }
  ]

  nlb_internal                     = false
  enable_cross_zone_load_balancing = true
  enable_security_groups           = true
  enable_tls_termination           = true  # Enable TLS at NLB level

  acm_certificate_arn = module.public_acm.certificate_arn
  route_53_zone_id    = data.aws_route53_zone.public.id
  nlb_domain          = var.elb_public_nlb_domain

  tags = local.tags
}
```

## variables.tf

```terraform
# NLB Module - Core Configuration
variable "environment" {
  type        = string
  description = "Environment name (staging, production, etc.)"
}

variable "app_name" {
  type        = string
  description = "Application name"
}

variable "elb_restricted_source_ips" {
  description = "List of CIDR blocks allowed to access the NLB"
  type        = list(string)
}

# NLB Fixed IP Configuration
variable "nlb_fixed_ip_subnet_id" {
  description = "Subnet ID for the NLB fixed IP address"
  type        = string
}

variable "nlb_fixed_ip_address" {
  description = "Fixed private IPv4 address for the NLB"
  type        = string
}

# NLB Domain Configuration
variable "elb_nest_nlb_domain" {
  description = "Domain name for the Nest NLB in Route53"
  type        = string
}

variable "elb_nuxt_nlb_domain" {
  description = "Domain name for the Nuxt NLB in Route53"
  type        = string
}

variable "elb_public_nlb_domain" {
  description = "Domain name for the public NLB in Route53"
  type        = string
}
```

## terraform.tfvars

```hcl
# NLB Module Configuration
environment = "staging"
app_name    = "welfan-namecard"

# Allowed source IPs for NLB security group
elb_restricted_source_ips = [
  "10.22.0.0/16",              # Internal VPC CIDR
  "203.0.113.0/24"             # Example partner IP range
]

# NLB Fixed IP Configuration (Nest)
nlb_fixed_ip_subnet_id = "subnet-0d052d81b1c098346"
nlb_fixed_ip_address   = "192.168.26.186"

# NLB Domain Names
elb_nest_nlb_domain  = "nest-api.internal.welfan.local"
elb_nuxt_nlb_domain  = "web.internal.welfan.local"
elb_public_nlb_domain = "api.welfan.com"
```

## Module Configuration Options

### NLB Placement

| Option                 | Description                             |
| ---------------------- | --------------------------------------- |
| `nlb_internal = true`  | Internal NLB accessible only within VPC |
| `nlb_internal = false` | Internet-facing NLB publicly accessible |

### IP Address Configuration

| Option                                        | Use Case                                   |
| --------------------------------------------- | ------------------------------------------ |
| `use_fixed_ips = false` with `subnet_ids`     | Dynamic IPs, multiple subnets for HA       |
| `use_fixed_ips = true` with `subnet_mappings` | Fixed private IPs for internal services    |
| `use_fixed_ips = true` with `allocation_id`   | Fixed Elastic IPs for internet-facing NLBs |

### Security & Listeners

| Option                                    | Description                                             |
| ----------------------------------------- | ------------------------------------------------------- |
| `enable_security_groups = true`           | Control access via security group rules                 |
| `enable_tls_termination = true`           | TLS/SSL termination at NLB (requires ACM certificate)   |
| `enable_tls_termination = false`          | TLS termination at application level (TCP pass-through) |
| `enable_cross_zone_load_balancing = true` | Distribute traffic across AZs                           |

## Security Group Rules Created

The module automatically creates a security group with:

- **Ingress Port 443** - HTTPS from restricted source IPs
- **Ingress Port 80** - HTTP from restricted source IPs
- **Ingress Port 10443** - Custom test port from VPC CIDR
- **Ingress ICMP** - Ping/diagnostics from restricted source IPs
- **Egress** - All traffic allowed outbound

## Outputs

```terraform
# Access outputs:
module.nlb_nest.nlb_arn              # ARN of the NLB
module.nlb_nest.nlb_security_group_id # Security group ID
module.nlb_nest.nlb_arn_suffix        # ARN suffix for CloudWatch metrics
module.nlb_nest.id                    # NLB ID
module.nlb_nest.dns_name              # AWS DNS name (e.g., nlb-123.elb.amazonaws.com)
module.nlb_nest.zone_id               # Route53 hosted zone ID for the NLB
module.nlb_nest.nlb_ip_addresses      # List of IP addresses (fixed or dynamic)
module.nlb_nest.lb_listener_tls_prod_arn  # TLS listener ARN (if enabled)
module.nlb_nest.lb_listener_tls_test_arn  # Test TLS listener ARN (if enabled)
```

## Integration with Route53

When creating the NLB, you can automatically create a Route53 DNS record:

```terraform
# The module can create Route53 records if:
# - route_53_zone_id is provided
# - nlb_domain is specified
# - create_route53_record = true (default)

# ECS modules will then reference this domain for target registration
```

## Integration with ECS

The NLB works seamlessly with ECS:

1. NLB creates a default target group and security group
2. ECS modules create their own target groups and listener rules
3. ECS services register with their respective target groups
4. NLB routes traffic based on listener rules (port/path)

Example ECS listener rule configuration:

```terraform
# ECS module would create listener rules like:
# Port 443 -> application target group
# Port 10443 -> test application target group
```

## Best Practices

1. **Fixed IPs for Internal Services**: Use fixed private IPs for DNS consistency
2. **Dynamic IPs for Public**: Use Elastic IPs for internet-facing NLBs
3. **Security Groups**: Always enable security groups to control ingress traffic
4. **Cross-Zone LB**: Enable for better availability across multiple AZs
5. **Health Checks**: Configure appropriate health check parameters in target groups
6. **TLS Termination**: Choose between NLB (for performance) or app-level (for flexibility)
7. **Monitoring**: Use CloudWatch metrics with `nlb_arn_suffix` for detailed monitoring
