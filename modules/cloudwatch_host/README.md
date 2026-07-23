# cloudwatch_host

Standalone CloudWatch **log group** + **single-EC2-host alarms** (CPU, StatusCheckFailed, memory,
disk) wired to an SNS topic. Fills the library gap — the existing `cloudwatch_alarm_*` modules cover
ECS/RDS/ElastiCache, not a plain EC2 host.

## CloudWatch-agent requirement

The memory and disk alarms read `CWAgent` metrics on the **`InstanceId` dimension only**, so the
CloudWatch agent config on the host must emit them aggregated to InstanceId, e.g.:

```json
{ "metrics": {
  "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
  "aggregation_dimensions": [["InstanceId"]],
  "metrics_collected": {
    "mem":  { "measurement": ["mem_used_percent"] },
    "disk": { "measurement": ["used_percent"], "resources": ["/"] }
  }
}}
```

Set `create_memory_alarm`/`create_disk_alarm = false` if the agent isn't emitting them yet.

## Usage

```hcl
module "host_obs" {
  source         = "../../modules/cloudwatch_host"
  app_name       = "myapp-prod"
  instance_id    = module.ec2.instance_id
  sns_topic_arn  = module.chatbot_slack.chatbot_sns_topic_arn
  log_group_name = "/myapp/prod/app"
  tags           = local.tags
}
```

## Inputs (required)

| Name | Description |
|------|-------------|
| `app_name` | Naming prefix. |
| `instance_id` | EC2 instance ID (metric dimension). |
| `sns_topic_arn` | SNS topic for alarm/OK actions. |
| `log_group_name` | Log group name. |

Optional: `log_retention_in_days` (30), `log_kms_key_id` (null), `cpu_threshold` (85),
`memory_threshold` (85), `disk_threshold` (85), `create_memory_alarm`/`create_disk_alarm` (true),
`cwagent_namespace` (CWAgent), `period` (300), `evaluation_periods` (2), `tags`.

## Outputs

`log_group_name`, `log_group_arn`, `alarm_arns` (map).
