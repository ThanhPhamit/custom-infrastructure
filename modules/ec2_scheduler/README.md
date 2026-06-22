# ec2_scheduler

Start/stop a set of EC2 instances on a cron schedule using **EventBridge Scheduler**
universal targets (`aws-sdk:ec2:startInstances` / `stopInstances`). **No Lambda** — the
scheduler calls the EC2 API directly via a scoped IAM role.

Use it to power non-prod environments down off-hours: EC2 bills **no compute** while stopped
(EBS volumes and Elastic IPs still bill). A weekday 08:00–20:00 window saves ≈65% of compute.

## Usage

```hcl
module "ec2_scheduler" {
  source = "../../modules/ec2_scheduler"

  app_name      = "tokyo-staging-hinerism"
  instance_arns = [module.ec2_web.instance_arn, module.ec2_db.instance_arn]

  start_expression = "cron(0 8 ? * MON-FRI *)"   # 08:00
  stop_expression  = "cron(0 20 ? * MON-FRI *)"  # 20:00
  timezone         = "Asia/Tokyo"
  enabled          = true

  tags = local.tags
}
```

## Notes
- Instance IDs are derived from `instance_arns`; the IAM policy is scoped to exactly those ARNs.
- `enabled = false` keeps both schedules but DISABLED (instances stay running).
- Terraform does not manage instance power state, so it never fights the scheduler.
- Cron format is EventBridge's `cron(min hour day-of-month month day-of-week year)`; `timezone`
  is IANA (e.g. `Asia/Tokyo`), so no manual UTC offset.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `app_name` | Naming prefix | — (required) |
| `instance_arns` | EC2 instance ARNs to start/stop | — (required) |
| `start_expression` | Start cron | `cron(0 8 ? * MON-FRI *)` |
| `stop_expression` | Stop cron | `cron(0 20 ? * MON-FRI *)` |
| `timezone` | IANA timezone | `Asia/Tokyo` |
| `enabled` | Enable schedules | `true` |
| `tags` | Tag map | `{}` |

## Outputs

`start_schedule_arn`, `stop_schedule_arn`, `scheduler_role_arn`, `managed_instance_ids`.
