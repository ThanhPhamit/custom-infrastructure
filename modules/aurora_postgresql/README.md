# aurora_postgresql

Private, encrypted **Aurora PostgreSQL (provisioned)** cluster for the s2s-vpn lab.

## Purpose

Provisions an Aurora PostgreSQL cluster designed to be reached only from inside the VPC (and from
on-prem over the Site-to-Site VPN), with security hardening and observability turned on but kept
teardown-friendly:

- **RDS-managed master secret** — `manage_master_user_password = true`; the password lives in
  Secrets Manager, never in state-as-plaintext-tfvars. `master_password` is never set.
- **IAM database authentication** — enabled by default so on-prem clients can mint short-lived
  RDS-IAM auth tokens instead of using a static password.
- **TLS forced** — a custom cluster parameter group sets `rds.force_ssl = 1` (apply method
  `pending-reboot`). Pair with `sslmode=verify-full` and the regional RDS CA bundle on the client.
- **Encryption at rest** — `storage_encrypted = true`; `kms_key_id = null` uses the AWS-managed
  `aws/rds` key (no lingering customer CMK to clean up).
- **Observability on** — Performance Insights, Enhanced Monitoring (with a dedicated IAM role),
  and PostgreSQL log export to CloudWatch Logs. Optional RDS event subscription and optional
  per-instance CPU alarms.
- **Teardown-friendly defaults** — `deletion_protection = false`, `skip_final_snapshot = true`,
  1-day backups, `apply_immediately = true`.

> **Engine version:** `engine_version` must be a version actually available in the target region.
> The operator confirms availability (e.g. via `aws rds describe-db-engine-versions`); this module
> does not validate availability, only the version string format.
>
> **KMS:** `kms_key_id = null` uses the AWS-managed `aws/rds` key. Supply a CMK ARN only if you
> need custom key rotation/control.

## Usage

```hcl
module "aurora" {
  source = "../../modules/aurora_postgresql"

  app_name            = "s2s-vpn-lab"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids   # >= 2 across AZs
  allowed_cidr_blocks = ["192.168.0.0/22", "10.0.0.0/24"]   # VPC + on-prem over S2S VPN

  engine_version = "16.6"
  instance_class = "db.t4g.medium"
  instance_count = 1

  # Observability / notifications (optional)
  event_subscription_sns_topic_arn = aws_sns_topic.alerts.arn
  enable_alarms                    = true
  alarm_actions                    = [aws_sns_topic.alerts.arn]

  tags = {
    Project = "s2s-vpn-lab"
    Env     = "lab"
  }
}
```

The on-prem client then connects over the VPN using the writer endpoint and either the RDS-managed
secret (`master_user_secret_arn`) or an IAM auth token, always with TLS.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | `string` | _required_ | Name prefix for all resources and the `Name` tag. |
| `vpc_id` | `string` | _required_ | VPC ID for the cluster security group. |
| `subnet_ids` | `list(string)` | _required_ | DB subnet group members (>= 2 across AZs). |
| `allowed_cidr_blocks` | `list(string)` | _required_ | CIDRs allowed inbound on 5432. |
| `engine_version` | `string` | `"16.6"` | Aurora PostgreSQL engine version (region-availability is the operator's responsibility). |
| `instance_class` | `string` | `"db.t4g.medium"` | Instance class per cluster instance. |
| `instance_count` | `number` | `1` | Number of cluster instances (>= 1). |
| `master_username` | `string` | `"dbadmin"` | Master username (password RDS-managed). |
| `database_name` | `string` | `null` | Initial database name (null = none). |
| `backup_retention_period` | `number` | `1` | Automated backup retention in days (1-35). |
| `deletion_protection` | `bool` | `false` | Deletion protection (keep false for teardown). |
| `skip_final_snapshot` | `bool` | `true` | Skip final snapshot on destroy. |
| `apply_immediately` | `bool` | `true` | Apply changes immediately. |
| `storage_encrypted` | `bool` | `true` | Encryption at rest. |
| `kms_key_id` | `string` | `null` | KMS key ARN/ID (null = AWS-managed `aws/rds`). |
| `iam_database_authentication_enabled` | `bool` | `true` | Enable IAM DB auth. |
| `force_ssl` | `bool` | `true` | Add `rds.force_ssl=1` cluster parameter. |
| `performance_insights_enabled` | `bool` | `true` | Enable Performance Insights. |
| `performance_insights_retention_period` | `number` | `7` | PI retention in days. |
| `monitoring_interval` | `number` | `60` | Enhanced Monitoring seconds (0 disables). |
| `enabled_cloudwatch_logs_exports` | `list(string)` | `["postgresql"]` | Log types to export. |
| `preferred_backup_window` | `string` | `"16:00-17:00"` | UTC backup window. |
| `event_subscription_sns_topic_arn` | `string` | `null` | SNS topic for RDS events (null = none). |
| `enable_alarms` | `bool` | `false` | Create per-instance CPU alarms. |
| `alarm_actions` | `list(string)` | `[]` | SNS ARNs for alarm actions. |
| `alarm_cpu_threshold` | `number` | `80` | CPU% threshold for the alarm. |
| `tags` | `map(string)` | `{}` | Additional tags merged onto resources. |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_identifier` | Cluster identifier. |
| `cluster_arn` | Cluster ARN. |
| `cluster_endpoint` | Writer (primary) endpoint. |
| `cluster_reader_endpoint` | Reader endpoint. |
| `cluster_port` | Connection port. |
| `cluster_resource_id` | Cluster resource ID (for `rds-db:connect` IAM ARNs). |
| `master_user_secret_arn` | ARN of the RDS-managed master secret (null if unmanaged). |
| `security_group_id` | Cluster security group ID. |
| `db_subnet_group_name` | DB subnet group name. |
