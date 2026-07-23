# vpc_flow_logs

Captures **VPC Flow Logs** to a CloudWatch Logs group, with a least-privilege delivery role. Closes
the "no network forensics" gap — essential on any host with open egress, as a compensating control
for that risk.

VPC Flow Logs are **not** on by default and have no hidden store — without this module there is zero
network flow data retained anywhere.

## Cost

The feature is free; you pay CloudWatch Logs ingestion (~$0.50/GB, vended-logs) + storage
(~$0.03/GB/mo). For a single low-traffic host this is typically a few $/month. Levers: `retention_days`,
`max_aggregation_interval = 600` (default, 10-min = fewer records), or `traffic_type = "REJECT"`
(much less volume, but ALL is better for exfil detection).

## Usage

```hcl
module "flow_logs" {
  source   = "../../modules/vpc_flow_logs"
  app_name = "myapp-prod"
  vpc_id   = module.network.vpc_id
  tags     = local.tags
}
```

## Inputs (required)

| Name | Description |
|------|-------------|
| `app_name` | Naming prefix. |
| `vpc_id` | VPC to capture. |

Optional: `traffic_type` (ALL), `retention_days` (30), `max_aggregation_interval` (600),
`log_kms_key_id` (null), `tags`.

## Outputs

`flow_log_id`, `log_group_name`, `log_group_arn`, `iam_role_arn`.

## Notes

- Log group uses default CloudWatch encryption (set `log_kms_key_id` + a `logs.<region>.amazonaws.com`
  CMK grant if a CMK is required).
- No alarm is created here (passive forensic capture). Layer a metric-filter alarm (or GuardDuty,
  which consumes flow data automatically) on top if you want active egress-anomaly alerting.
