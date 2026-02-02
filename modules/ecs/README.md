# ECS Server Module

This module deploys an ECS Fargate service with Application Load Balancer (ALB) or Network Load Balancer (NLB) integration, supporting Blue/Green deployments via AWS CodeDeploy.

## Features

- ✅ ECS Fargate tasks with customizable CPU/Memory
- ✅ ALB or NLB integration with health checks
- ✅ Blue/Green deployment support (CODE_DEPLOY controller)
- ✅ Automatic secrets management (AWS Secrets Manager)
- ✅ CloudWatch Logs integration
- ✅ **Flexible network configuration (private or public subnets)**
- ✅ Auto-scaling ready with target groups
- ✅ ECR integration for container images

## Network Deployment Options

This module supports **two deployment strategies** based on your network architecture and cost requirements:

### 1. Private Subnet Deployment (Production Recommended)

**Use Case:** Production environments requiring enhanced security and isolation.

**Network Architecture:**
```
Internet → IGW → ALB (Public Subnet) → ECS Tasks (Private Subnet) → NAT Gateway → Internet
                                      ↓
                                   RDS/ElastiCache (Database Subnet)
```

**Configuration:**
```hcl
module "ecs_server" {
  source = "../../modules/ecs_server"
  
  # Network - PRIVATE subnets (with NAT Gateway)
  subnet_ids       = module.vpc.private_subnet_ids
  assign_public_ip = false  # Tasks do NOT get public IPs
  
  # ... other configuration
}
```

**Characteristics:**
- ✅ **Security:** ECS tasks have no direct internet access, protected by NAT Gateway
- ✅ **Best Practice:** Recommended for production workloads
- ✅ **Database Access:** Direct access to RDS/ElastiCache in private subnets
- ❌ **Cost:** NAT Gateway charges (~$32/month per AZ + data transfer)
- ✅ **AWS Services:** Access AWS services (Secrets Manager, ECR, S3) via NAT Gateway
- ✅ **Outbound Only:** NAT Gateway provides outbound internet access only

**Requirements:**
- NAT Gateway must be configured in VPC
- Private subnets must route `0.0.0.0/0` to NAT Gateway
- VPC endpoints (optional but recommended for cost optimization)

---

### 2. Public Subnet Deployment (Cost-Optimized)

**Use Case:** Development, demo, or staging environments where cost optimization is priority.

**Network Architecture:**
```
Internet → IGW → ALB (Public Subnet) → ECS Tasks (Public Subnet with Public IP) → IGW → Internet
                                      ↓
                                   RDS/ElastiCache (Database Subnet)
```

**Configuration:**
```hcl
module "ecs_server" {
  source = "../../modules/ecs_server"
  
  # Network - PUBLIC subnets (no NAT Gateway)
  subnet_ids       = module.vpc.public_subnet_ids
  assign_public_ip = true  # Required! Tasks MUST get public IPs
  
  # ... other configuration
}
```

**Characteristics:**
- ✅ **Cost Saving:** No NAT Gateway charges (saves ~$32-96/month)
- ✅ **AWS Services:** Direct access to Secrets Manager, ECR, S3 via Internet Gateway
- ✅ **Database Access:** Can access RDS/ElastiCache in private subnets (same VPC)
- ⚠️ **Security:** Tasks have public IPs but protected by Security Groups
- ⚠️ **Exposure:** Each task has a public IP (inbound blocked by Security Group)
- ✅ **Simple Routing:** Public subnet routes `0.0.0.0/0` to Internet Gateway

**Requirements:**
- **`assign_public_ip = true` is MANDATORY** - Without public IP, tasks cannot reach AWS services
- Public subnets must route `0.0.0.0/0` to Internet Gateway
- Security Group must allow outbound traffic to `0.0.0.0/0`
- ALB/NLB must be in public subnets

**⚠️ Common Error:**
If `assign_public_ip = false` in public subnets, you'll see:
```
ResourceInitializationError: unable to pull secrets or registry auth: 
unable to retrieve secret from asm: There is a connection issue between 
the task and AWS Secrets Manager.
```

---

## Comparison Table

| Feature | Private Subnet + NAT Gateway | Public Subnet + Public IP |
|---------|------------------------------|---------------------------|
| **Monthly Cost (NAT)** | ~$32-96/month | $0 (no NAT) |
| **Security Posture** | ⭐⭐⭐⭐⭐ High | ⭐⭐⭐ Medium |
| **Production Ready** | ✅ Yes (Recommended) | ⚠️ Acceptable for non-critical |
| **Task Public IP** | ❌ No | ✅ Yes (auto-assigned) |
| **Internet Access** | Via NAT Gateway | Direct via IGW |
| **AWS Service Access** | Via NAT Gateway | Direct via IGW |
| **Database Access** | ✅ Direct (private) | ✅ Direct (private) |
| **Use Cases** | Production, Staging | Dev, Demo, Cost-sensitive |
| **assign_public_ip** | `false` | `true` (required) |

---

## Usage Examples

### Example 1: Production (Private Subnet)

```hcl
# VPC with NAT Gateway
module "vpc" {
  source = "../../modules/network"
  
  enable_nat_gateway = true
  single_nat_gateway = true  # or false for HA (multi-AZ)
  
  # ... other config
}

# ECS Server in Private Subnets
module "ecs_server" {
  source = "../../modules/ecs_server"
  
  app_name = "prod-my-app"
  region   = "ap-northeast-1"
  vpc_id   = module.vpc.vpc_id
  
  # Container
  container_names       = ["server"]
  container_port        = 8000
  app_health_check_path = "/health"
  
  # Network - PRIVATE with NAT Gateway
  subnet_ids       = module.vpc.private_subnet_ids
  assign_public_ip = false
  
  # Load Balancer (ALB)
  load_balancer_type     = "alb"
  http_prod_listener_arn = module.alb.lb_listener_http_prod_arn
  http_test_listener_arn = module.alb.lb_listener_http_test_arn
  alb_security_group_id  = module.alb.alb_security_group_id
  
  # Security
  ecs_security_group_id = aws_security_group.ecs_tasks.id
  
  # ECR
  repository_url = module.ecr.repository_url
  repository_arn = module.ecr.repository_arn
  
  # Resources
  desired_task_count = 2
  task_cpu_size      = 512
  task_memory_size   = 1024
  
  # Environment variables
  environment = "PRODUCTION"
  postgres_host = module.rds.db_hostname
  # ... other vars
  
  # Secrets
  postgres_password_secret_arn = module.rds.password_secret_arn
  # ... other secrets
  
  tags = local.tags
}
```

### Example 2: Demo/Dev (Public Subnet - Cost Optimized)

```hcl
# VPC without NAT Gateway
module "vpc" {
  source = "../../modules/network"
  
  enable_nat_gateway = false  # No NAT Gateway for cost saving
  single_nat_gateway = false
  
  # ... other config
}

# ECS Server in Public Subnets
module "ecs_server" {
  source = "../../modules/ecs_server"
  
  app_name = "demo-my-app"
  region   = "ap-northeast-1"
  vpc_id   = module.vpc.vpc_id
  
  # Container
  container_names       = ["server"]
  container_port        = 8000
  app_health_check_path = "/health"
  
  # Network - PUBLIC without NAT Gateway
  subnet_ids       = module.vpc.public_subnet_ids
  assign_public_ip = true  # REQUIRED for public subnet deployment!
  
  # Load Balancer (ALB)
  load_balancer_type     = "alb"
  http_prod_listener_arn = module.alb.lb_listener_http_prod_arn
  http_test_listener_arn = module.alb.lb_listener_http_test_arn
  alb_security_group_id  = module.alb.alb_security_group_id
  
  # Security
  ecs_security_group_id = aws_security_group.ecs_tasks.id
  
  # ECR
  repository_url = module.ecr.repository_url
  repository_arn = module.ecr.repository_arn
  
  # Resources (minimal for demo)
  desired_task_count = 1
  task_cpu_size      = 256
  task_memory_size   = 512
  
  # Environment variables
  environment = "DEMO"
  postgres_host = module.rds.db_hostname
  # ... other vars
  
  # Secrets
  postgres_password_secret_arn = module.rds.password_secret_arn
  # ... other secrets
  
  tags = local.tags
}
```

---

## Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `app_name` | string | Application name prefix |
| `region` | string | AWS region |
| `vpc_id` | string | VPC ID |
| `container_names` | list(string) | Container names in task definition |
| `container_port` | number | Container port number |
| `cluster_name` | string | ECS cluster name |
| `subnet_ids` | list(string) | Subnet IDs for ECS tasks (private or public) |
| `assign_public_ip` | bool | **Assign public IP to tasks (required for public subnets)** |
| `http_prod_listener_arn` | string | Production listener ARN |
| `http_test_listener_arn` | string | Test listener ARN |
| `ecs_security_group_id` | string | Security group ID for ECS tasks |
| `repository_url` | string | ECR repository URL |
| `repository_arn` | string | ECR repository ARN |

## Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `desired_task_count` | number | 1 | Number of tasks to run |
| `task_cpu_size` | number | 256 | Task CPU units (256 = 0.25 vCPU) |
| `task_memory_size` | number | 512 | Task memory in MB |
| `app_health_check_path` | string | `/health` | Health check endpoint |
| `load_balancer_type` | string | `"alb"` | Load balancer type (`alb` or `nlb`) |
| `environment` | string | `"PRODUCTION"` | Environment name |

---

## Outputs

| Output | Description |
|--------|-------------|
| `service_name` | ECS service name |
| `task_definition_arn` | Task definition ARN |
| `lb_target_group_blue_name` | Blue target group name |
| `lb_target_group_green_name` | Green target group name |
| `lb_target_group_blue_arn_suffix` | Blue target group ARN suffix |
| `lb_target_group_green_arn_suffix` | Green target group ARN suffix |
| `ecs_task_role_arn` | Task role ARN |
| `ecs_task_execution_role_arn` | Task execution role ARN |
| `ecs_cloudwatch_log_group_name` | CloudWatch log group name |

---

## Security Considerations

### Private Subnet (Recommended)
- ✅ Tasks have no public IPs - better attack surface reduction
- ✅ All outbound traffic goes through NAT Gateway
- ✅ Can use VPC endpoints to avoid NAT Gateway data charges
- ✅ Compliant with most security frameworks

### Public Subnet (Use with Caution)
- ⚠️ Each task gets a public IP address
- ✅ Inbound traffic blocked by Security Group (only ALB can connect)
- ✅ Outbound traffic allowed for AWS service access
- ⚠️ Consider using VPC endpoints for sensitive services
- ⚠️ Monitor CloudTrail logs for unauthorized access attempts

### Security Group Configuration (Both Cases)

```hcl
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "ecs-tasks-"
  vpc_id      = module.vpc.vpc_id
  
  # Allow inbound from ALB only
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
  }
  
  # Allow all outbound (required for AWS services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Troubleshooting

### Error: Cannot pull secrets from Secrets Manager

**Symptom:**
```
ResourceInitializationError: unable to pull secrets or registry auth: 
unable to retrieve secret from asm
```

**Cause:** Tasks in public subnets without public IPs cannot reach AWS services.

**Solution:** Set `assign_public_ip = true` when using public subnets.

### Error: Cannot pull ECR images

**Symptom:**
```
CannotPullContainerError: Error response from daemon
```

**Causes & Solutions:**
1. **Public subnet without public IP:** Set `assign_public_ip = true`
2. **Private subnet without NAT:** Enable NAT Gateway in VPC module
3. **IAM permissions:** Ensure task execution role has ECR pull permissions (automatically configured by this module)

### High NAT Gateway Costs

**Solution:** Consider using VPC endpoints for frequently accessed AWS services:
- `com.amazonaws.region.ecr.api` - ECR API
- `com.amazonaws.region.ecr.dkr` - ECR Docker
- `com.amazonaws.region.secretsmanager` - Secrets Manager
- `com.amazonaws.region.logs` - CloudWatch Logs

---

## Best Practices

1. **Production:** Use private subnets with NAT Gateway or VPC endpoints
2. **Dev/Demo:** Use public subnets with `assign_public_ip = true` to save costs
3. **Security:** Always restrict Security Group ingress to ALB/NLB only
4. **Monitoring:** Enable CloudWatch Container Insights for performance monitoring
5. **Secrets:** Never hardcode secrets - always use AWS Secrets Manager
6. **Scaling:** Configure auto-scaling based on CloudWatch metrics
7. **Health Checks:** Implement comprehensive health check endpoints

---

## License

This module is maintained by the infrastructure team.
