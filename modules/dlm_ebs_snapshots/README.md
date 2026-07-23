# dlm_ebs_snapshots

Amazon Data Lifecycle Manager (DLM) policy for scheduled EBS snapshots, plus its own service role.
Self-contained — creates the `dlm.amazonaws.com` execution role with the AWS-managed
`AWSDataLifecycleManagerServiceRole` policy.

## Targeting the DATA volume only

Set `resource_type = "INSTANCE"`, tag the **instance** with `target_tags`, and keep
`exclude_boot_volume = true`. DLM then snapshots the instance's attached volumes *except* the boot
volume — i.e. only the data volume (avoids snapshotting a large baked-toolchain root).

## Usage

```hcl
module "dlm" {
  source        = "../../modules/dlm_ebs_snapshots"
  app_name      = "myapp-prod"
  resource_type = "INSTANCE"
  target_tags   = { Backup = "myapp-daily" }          # also put this tag on the instance
  schedule_times = ["17:00"]                          # UTC
  retain_count  = 14
  tags          = local.tags
}
```

## Inputs (required)

| Name | Description |
|------|-------------|
| `app_name` | Naming prefix. |
| `target_tags` | Tag map selecting resources to snapshot. |

Optional: `resource_type` (INSTANCE), `exclude_boot_volume` (true), `schedule_interval_hours` (24),
`schedule_times` (["17:00"]), `retain_count` (14), `copy_tags` (true), `tags`.

## Outputs

`policy_id`, `policy_arn`, `execution_role_arn`.
