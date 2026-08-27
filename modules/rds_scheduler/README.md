# rds_scheduler

Start/stop RDS **DB instances** on a cron, via EventBridge Scheduler **universal targets** — no
Lambda, no SSM document, no code to maintain. Sibling of `ec2_scheduler`, deliberately the same
interface so an environment can schedule both tiers the same way.

```hcl
module "rds_scheduler" {
  source = "../../modules/rds_scheduler"

  app_name         = local.app_name
  db_instance_arns = [module.rds.db_instance_arn]

  start_expression = "cron(45 7 ? * MON-FRI *)"
  stop_expression  = "cron(10 19 ? * MON-FRI *)"
  timezone         = "Asia/Tokyo"
  tags             = local.tags
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | string | — | Naming prefix for schedules + IAM role |
| `db_instance_arns` | list(string) | — | DB **instance** ARNs; identifiers derived from them, IAM scoped to them |
| `start_expression` | string | `cron(0 8 ? * MON-FRI *)` | EventBridge Scheduler cron |
| `stop_expression` | string | `cron(0 20 ? * MON-FRI *)` | EventBridge Scheduler cron |
| `timezone` | string | `Asia/Tokyo` | IANA zone the crons are evaluated in |
| `enabled` | bool | `true` | `false` = schedules exist but DISABLED |
| ``retry_maximum_attempts`` | number | `10` | Retry attempts for a failed invocation. AWS defaults to 185 (with a 24 h age) — wrong for a STOP schedule: a 19:00 stop that keeps retrying can succeed at 10:00 the next working day. |
| ``retry_maximum_event_age_seconds`` | number | `3600` | How long a failed invocation stays retryable. Keeps retries inside the window the schedule was meant for. |
| ``dead_letter_arn`` | string | `null` | SQS queue for invocations that fail every retry. `null` = **no dead letter**, so a permanently failed start/stop is silent. The module does not create the queue — one queue usually serves several schedulers. |
| `tags` | map(string) | `{}` | Merged with `Name` + `ManagedBy` |

## Outputs

`start_schedule_arns` · `stop_schedule_arns` (both keyed by DB identifier) · `scheduler_role_arn` ·
`managed_db_identifiers`

## Things that will bite you

**A stopped RDS instance is not a free RDS instance.** Compute stops billing; **storage, backups and
snapshots do not**. On a `db.t4g.micro` + 20 GB gp3 that means roughly the instance hour goes away
and a few dollars of storage stays. Size the expectation accordingly — this saves a fraction, not
the whole line.

**AWS force-starts a stopped instance after 7 days.** Stop it on a Friday with a Monday start and
you are fine; disable the start schedule for a two-week shutdown and RDS will start it for you on
day 7 and leave it running. For a genuine long shutdown, snapshot and delete instead.

**One identifier per API call.** `rds:StopDBInstance` has no batch form, so this module creates two
schedules per database rather than one pair for all of them. That is why `for_each` is over the
identifiers and the schedule names carry the DB name.

**Aurora is not this module.** Aurora starts and stops at the *cluster* level
(`rds:StartDBCluster`), which is a different API and a different ARN shape. The `db_instance_arns`
validation rejects `:cluster:` ARNs rather than letting them fail at apply.

**Order the tiers, do not fire them together.** A database takes minutes to become `available`.
If the application tier starts at the same moment it will come up, fail to connect, and restart
until the DB answers. Start the database *first* (10–15 min of headroom) and stop it *last*, so the
app has closed its connections before the engine goes down.

**A scheduled stop will trip an "instance down" alarm** unless that alarm was written for it. An
alarm whose `treat_missing_data` is `breaching` fires on every scheduled stop, and an alarm that
pages nightly is an alarm the team learns to ignore. See `cloudwatch_host`'s
`status_check_treat_missing_data` for the equivalent knob on the EC2 side.

**Reaching the app outside the window** is a manual start, not an emergency:
`aws rds start-db-instance --db-instance-identifier <id>` then the EC2 instance. The schedule will
stop it again at the next stop time — it does not "remember" that a human wanted it up.
