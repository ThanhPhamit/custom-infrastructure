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

### `status_check_treat_missing_data` — read this before scheduling the host

Default `"breaching"`. `StatusCheckFailed` simply **stops publishing** when an instance is stopped or
terminated, so on a host that is meant to be up 24/7 the absence of data *is* the failure signal, and
`breaching` is correct.

It is wrong the moment the instance runs on a **start/stop schedule**: every scheduled shutdown
becomes an alarm, the channel gets a page every evening, and an alarm that cries wolf nightly is one
the team stops reading — which costs more than the detection it was meant to buy. Set
`"notBreaching"` there. You keep the alarm that matters: an instance that is *running but broken*
still publishes `StatusCheckFailed = 1` and still fires. What you give up is noticing an instance
that vanished outside working hours.

Accepted values: `breaching`, `notBreaching`, `ignore`, `missing` (validated).

### Scheduled hosts: two more alarms you almost certainly want

Setting `status_check_treat_missing_data = "notBreaching"` above closes the nightly-paging problem
and opens two holes. Both are optional extra alarms, both default **off**, and both were added after
a real nine-hour outage on 2026-08-26 that neither existing alarm could see.

| Variable | Answers | Needs a gate? |
|---|---|---|
| `create_host_absent_alarm` | "the host should be running right now and it is not there at all" — a failed start, a stopped instance, a terminated one | **Yes** |
| `create_schedule_overrun_alarm` | "the host is still running when it should have stopped" — a stop that silently did not happen | No |

**`create_host_absent_alarm`** is a second alarm on the same `StatusCheckFailed` metric with
`treat_missing_data = "breaching"`, empty `ok_actions`, and `actions_enabled` under `lifecycle`
`ignore_changes`. Ungated it pages on every scheduled stop, so pair it with the
`alarm_office_hours_gate` module, which disarms its actions outside working hours and — crucially —
resets it to OK each morning *after* re-arming, because enabling actions is not a state transition
and an alarm that sat in ALARM all night notifies nobody.

**`create_schedule_overrun_alarm`** + `schedule_overrun_max_minutes_per_day` (default 1000) counts
rather than samples, which is why it needs no gate: `StatusCheckFailed` publishes exactly one
datapoint per minute while the instance lives, so the daily `SampleCount` **is** the number of
minutes it ran. A 13-hour weekday window is 780; an instance that never stopped is 1440. Weekends
produce no data at all, hence `notBreaching`. A UTC day always contains exactly one such window, so
the threshold needs no correction for a non-UTC schedule.

## Outputs

`log_group_name`, `log_group_arn`, `alarm_arns` (map).
