# Osaka Staging Environment

Terraform infrastructure for **Remark AI Tool** - a scheduled ECS task running on AWS Fargate.

## 📁 Structure

```
osaka-stg/
├── main.tf              # ECS task, ECR, EventBridge
├── terraform.tfvars     # Configuration
├── variables.tf         # Variable definitions
├── providers.tf         # AWS provider
├── backend.tf          # Terraform state
├── locals.tf           # Local values
├── data.tf             # Data sources
└── outputs.tf          # Outputs
```

## 🚀 Quick Start

```bash
terraform init
terraform plan
terraform apply
```

**Verify:**

```bash
aws logs tail /ecs/stg-remark-ai-tool --follow
```

## 📦 Resources

- **ECS Cluster**: `stg-remark-ai-tool`
- **Task Definition**: 256 CPU / 512 MB
- **Schedule**: Every 30 minutes (configurable)
- **Log Group**: `/ecs/stg-remark-ai-tool`
- **ECR Repository**: `stg-remark-ai-tool`

## 🔧 Configuration

### Task Settings

```terraform
remark_ai_tool_task_cpu    = "256"
remark_ai_tool_task_memory = "512"
```

### Schedule

```terraform
remark_ai_tool_schedule = "rate(30 minutes)"
# Or: "rate(1 hour)", "cron(0 9 * * ? *)"
```

### Environment Variables

```terraform
remark_ai_tool_environment_vars = {
  DATABASE_HOST     = "10.x.x.x"
  DATABASE_PORT     = "1434"
  DATABASE_NAME     = "WELFAN_DB"
  DATABASE_USER     = "testLG"
  DATABASE_PASSWORD = "***"  # Use Secrets Manager in production
  DATABASE_SCHEMA   = "WELFAN"
}
```

## 📊 Monitoring

**CloudWatch Logs:** `/ecs/stg-remark-ai-tool`

**Expected Output:**

```
✅ Database connected successfully!
✅ Query executed successfully!
✅ Connection Test Completed Successfully
```

## 🔒 Security

- Private subnet (no public IP)
- S2S VPN to on-premise database
- IAM roles for task execution and application
- ⚠️ Use AWS Secrets Manager for production credentials

## 🔄 Updates

### Update Application

1. Build and push new Docker image to ECR
2. Update `main.tf` if needed
3. Run `terraform apply`

### Update Schedule

```terraform
# Edit terraform.tfvars
remark_ai_tool_schedule = "rate(1 hour)"

# Apply changes
terraform apply
```

## 🆘 Troubleshooting

```bash
# Check task status
aws ecs describe-tasks --cluster stg-remark-ai-tool --tasks <task-id>

# View logs
aws logs tail /ecs/stg-remark-ai-tool --follow

# Check EventBridge rule
aws events describe-rule --name stg-remark-ai-tool-schedule
```

## 💰 Cost Estimate

**Monthly (~$7-13):**

- ECS Fargate: ~$5-10
- CloudWatch Logs: ~$1-2
- ECR Storage: <$1

## 📚 Documentation

For detailed information, see:

- [Deployment Guide](../../docs/remark-ai-tool-scheduled-task.md)
- [Application README](../../../applications/remark-ai-tool/README.md)

---

**Environment**: osaka-stg  
**Region**: ap-northeast-3 (Osaka)  
**Managed By**: Terraform
