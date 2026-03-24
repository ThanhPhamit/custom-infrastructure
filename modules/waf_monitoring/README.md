# AWS WAF Monitoring Terraform Module

Terraform module that creates a complete **Monitoring & Diagnostic System** for AWS WAF. Designed to work alongside the `waf_standard` module, providing real-time alerting, visual dashboards, and long-term log storage for security analysis.

## Features

This module supports creating:

- **WAF Logging Configuration** — Connects Web ACL to S3 for full log capture
- **Amazon SNS** — Email alert notifications for abnormal traffic spikes and attack patterns
- **CloudWatch Alarms** — Real-time monitoring of blocked/counted requests per WAF rule (smart: 1 alarm per rule matched to action mode)
- **CloudWatch Dashboard** — Visual dashboard with summary cards and time-series charts
- **Amazon S3** — Full WAF log storage with lifecycle policies for cost-effective long-term retention
- **Amazon Athena** — Query-ready setup: Glue database/table, dedicated workgroup with cost control, separate results bucket with auto-cleanup
- **Athena-ready** — S3 logs partitioned by `year/month/day/hour` with projection for instant querying (no `MSCK REPAIR TABLE` needed)

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         waf_standard             │
                    │        (Web ACL Rules)           │
                    └───────────────┬─────────────────┘
                                    │ web_acl_arn
                                    │ active_rules (dynamic)
                    ┌───────────────▼─────────────────┐
                    │        waf_monitoring            │
                    │                                  │
                    │  ┌─ Real-time Alerting ────────┐ │
                    │  │ SNS Topic + Email Subs      │ │
                    │  │ CloudWatch Metric Alarms    │ │
                    │  │  (dynamic per active_rules) │ │
                    │  │  block→Blocked / count→     │ │
                    │  │  Counted (1 alarm per rule)  │ │
                    │  └─────────────────────────────┘ │
                    │                                  │
                    │  ┌─ Visual Dashboard ──────────┐ │
                    │  │ Summary Cards (top 3 rules) │ │
                    │  │ Blocked Requests Timeline   │ │
                    │  │ Counted Requests Timeline   │ │
                    │  │ Total Allowed Traffic       │ │
                    │  └─────────────────────────────┘ │
                    │                                  │
                    │  ┌─ S3 Full Logging ───────────┐ │
                    │  │ Encrypted (AES-256)         │ │
                    │  │ Versioned                   │ │
                    │  │ Lifecycle:                  │ │
                    │  │  30d → Standard-IA          │ │
                    │  │  90d → Glacier              │ │
                    │  │ 365d → Expire               │ │
                    │  └─────────────────────────────┘ │
                    │                                  │
                    │  ┌─ Athena Query Layer ───────┐  │
                    │  │ Glue DB + Table (WAF schema)│  │
                    │  │ Workgroup (1GB scan limit)  │  │
                    │  │ Results S3 (7d auto-delete) │  │
                    │  │ Partition projection        │  │
                    │  └─────────────────────────────┘  │
                    └─────────────────────────────────┘
```

## CloudWatch Alarms

Alarms are **dynamically generated** from the `active_rules` map passed by `waf_standard`. Each rule gets **one alarm** matched to its action mode:

- Rule in **`block`** mode → `BlockedRequests` alarm (detect active attacks being blocked)
- Rule in **`count`** mode → `CountedRequests` alarm (detect suspicious traffic in dry-run)

For example, with `service_type = "ALB"` (6 rules) all in `count` mode, the module creates **6 CountedRequests alarms**. As you switch rules to `block`, their alarms automatically change to `BlockedRequests` on the next `terraform apply`.

| Alarm Pattern          | Metric            | Default Threshold       |
| ---------------------- | ----------------- | ----------------------- |
| `*-{rule_key}-blocked` | `BlockedRequests` | 100 (50 for rate_limit) |
| `*-{rule_key}-counted` | `CountedRequests` | 500                     |

> Thresholds are configurable via `alarm_blocked_requests_threshold`, `alarm_counted_requests_threshold`, and `alarm_rate_limit_threshold`.
>
> Both `ALARM` and `OK` states trigger SNS notifications so the team knows when an incident starts **and** when it resolves.
>
> IP allowlist is automatically excluded from monitoring (it uses `allow` action, not block/count).

## CloudWatch Dashboard

The dashboard is **dynamically generated** from `active_rules`. Widget rows adapt to whichever rules are enabled:

| Row | Widget Type  | Content                                                                     |
| --- | ------------ | --------------------------------------------------------------------------- |
| 1   | Single Value | Summary cards: Blocked count for IP Reputation, Rate Limit, CRS (if active) |
| 2   | Time Series  | Blocked Requests by Rule (all active rules)                                 |
| 3   | Time Series  | Counted Requests by Rule (all active rules, monitor mode visibility)        |
| 4   | Time Series  | Total Allowed Requests (overall traffic baseline)                           |

## S3 Full Logging

The S3 bucket is configured with security best practices:

- **Public Access Block** — All public access blocked
- **Server-Side Encryption** — AES-256 with bucket key
- **Versioning** — Enabled for audit trail
- **Lifecycle Policy** — Automatic tiering for cost optimization
- **Bucket Policy** — Restricted to WAF log delivery service principal only

### Lifecycle Policy

```
Day 0 ──────── STANDARD (frequent access)
       │
Day 30 ──────── STANDARD_IA (infrequent, lower cost)
       │
Day 90 ──────── GLACIER (archive, lowest cost)
       │
Day 365 ─────── DELETE (expiration)
```

### Querying with Amazon Athena

Athena infrastructure is **automatically created** by this module (Glue database, table, workgroup, results bucket). No manual setup needed.

Partition projection is enabled — query any date range instantly without `MSCK REPAIR TABLE`.

```sql
-- Top 10 attacking IPs today
SELECT httprequest.clientip AS source_ip,
       COUNT(*) AS request_count, action
FROM waf_logs
WHERE action = 'BLOCK'
  AND year = YEAR(CURRENT_DATE)
  AND month = MONTH(CURRENT_DATE)
  AND day = DAY(CURRENT_DATE)
GROUP BY httprequest.clientip, action
ORDER BY request_count DESC
LIMIT 10;

-- Counted requests by rule (monitor mode analysis for count→block migration)
SELECT terminatingruleid, COUNT(*) AS cnt
FROM waf_logs
WHERE action = 'COUNT'
  AND year = YEAR(CURRENT_DATE) AND month = MONTH(CURRENT_DATE)
GROUP BY terminatingruleid
ORDER BY cnt DESC;

-- Recent traffic (last 50 requests today)
SELECT from_unixtime(timestamp/1000) AS ts,
       httprequest.clientip, httprequest.uri,
       action, terminatingruleid
FROM waf_logs
WHERE year = YEAR(CURRENT_DATE)
  AND month = MONTH(CURRENT_DATE)
  AND day = DAY(CURRENT_DATE)
ORDER BY timestamp DESC LIMIT 50;
```

> **Cost control:** Workgroup enforces a `bytes_scanned_cutoff_per_query` limit (default 1 GB). Queries exceeding this are automatically cancelled.

## Usage

### Basic Usage (with waf_standard)

```terraform
# 1. Create WAF rules (no logging — purely rules)
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  service_type = "ALB"

  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"
  body_size_action_mode        = "count"
  sql_injection_action_mode    = "count"
  known_bad_inputs_action_mode = "count"

  tags = local.tags
}

# 2. Create monitoring (all logging, alerts, dashboard)
module "waf_monitoring" {
  source       = "../../modules/waf_monitoring"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  web_acl_arn  = module.waf_alb.web_acl_arn
  active_rules = module.waf_alb.active_rules  # dynamic rule monitoring

  alert_emails  = ["security-team@example.com", "admin@example.com"]

  tags = local.tags
}
```

### Custom Thresholds

```terraform
module "waf_monitoring" {
  source       = "../../modules/waf_monitoring"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  web_acl_arn  = module.waf_alb.web_acl_arn
  active_rules = module.waf_alb.active_rules

  alert_emails = ["security@example.com"]

  # Stricter alarm thresholds
  alarm_blocked_requests_threshold = 50
  alarm_counted_requests_threshold = 200
  alarm_rate_limit_threshold       = 20
  alarm_evaluation_periods         = 2    # Must breach 2 consecutive periods
  alarm_period_seconds             = 60   # 1-minute evaluation window

  # Longer S3 retention
  s3_log_retention_days      = 730  # 2 years
  s3_transition_ia_days      = 60
  s3_transition_glacier_days = 180

  tags = local.tags
}
```

### Without Dashboard

```terraform
module "waf_monitoring" {
  source           = "../../modules/waf_monitoring"
  app_name         = "${var.environment}-${var.app_name}"
  scope            = "REGIONAL"
  web_acl_arn      = module.waf_alb.web_acl_arn
  active_rules     = module.waf_alb.active_rules
  alert_emails     = ["admin@example.com"]
  enable_dashboard = false

  tags = local.tags
}
```

## How It Connects to waf_standard

```
┌──────────────┐     web_acl_arn + active_rules   ┌──────────────────┐
│ waf_standard │ ─────────────────────────────►   │  waf_monitoring   │
│              │                                  │                  │
│ Web ACL      │                                  │ S3 Bucket        │
│ Rules        │ ── CW metrics (automatic) ──►    │ WAF Logging Cfg  │
│              │                                  │ CW Alarms (dyn)  │
│ active_rules │ ── rule map (dynamic) ──────►    │ CW Dashboard(dyn)│
│              │                                  │ SNS → Email      │
│              │                                  │ Athena (Glue+WG) │
└──────────────┘                                  └──────────────────┘
```

- **WAF Logging Config** → Created by `waf_monitoring`, connects the Web ACL (via `web_acl_arn`) to S3 for full log capture and long-term retention.
- **active_rules** → Map of rule key → `{metric_name, action_mode}`, output by `waf_standard`. Tells `waf_monitoring` exactly which rules are enabled and their action mode, so alarms are created as `BlockedRequests` (for `block` mode) or `CountedRequests` (for `count` mode). When you change `service_type`, toggle rules, or switch action modes, monitoring auto-adapts on the next `terraform apply`.
- **CloudWatch Metrics** → Automatically emitted by WAF rules (via `visibility_config`). The monitoring module reads these using the metric names from `active_rules`.
- **SNS Email Alerts** → Subscribers must **confirm** their email subscription (AWS sends a confirmation email after `terraform apply`).

## Inputs

| Name                             | Description                                                                     | Type           | Default             | Required |
| -------------------------------- | ------------------------------------------------------------------------------- | -------------- | ------------------- | :------: |
| app_name                         | Application name (must match waf_standard `app_name`)                           | `string`       | n/a                 |   yes    |
| scope                            | WAF scope: `CLOUDFRONT` or `REGIONAL`                                           | `string`       | n/a                 |   yes    |
| alert_emails                     | Email addresses to receive WAF alert notifications                              | `list(string)` | n/a                 |   yes    |
| web_acl_arn                      | ARN of the WAF Web ACL to attach logging to                                     | `string`       | n/a                 |   yes    |
| active_rules                     | Map of rule key → `{metric_name, action_mode}` from `waf_standard.active_rules` | `map(object)`  | n/a                 |   yes    |
| **S3 Full Logging**              |                                                                                 |                |                     |          |
| s3_log_retention_days            | Days to retain logs in S3 before deletion                                       | `number`       | `365`               |    no    |
| s3_transition_ia_days            | Days before transitioning to STANDARD_IA                                        | `number`       | `30`                |    no    |
| s3_transition_glacier_days       | Days before transitioning to GLACIER                                            | `number`       | `90`                |    no    |
| **CloudWatch Alarms**            |                                                                                 |                |                     |          |
| alarm_blocked_requests_threshold | Threshold for blocked requests alarms (sum per period)                          | `number`       | `100`               |    no    |
| alarm_counted_requests_threshold | Threshold for counted requests alarms (sum per period)                          | `number`       | `500`               |    no    |
| alarm_rate_limit_threshold       | Threshold for rate limit rule alarms (sum per period)                           | `number`       | `50`                |    no    |
| alarm_evaluation_periods         | Consecutive periods metric must breach to trigger alarm                         | `number`       | `1`                 |    no    |
| alarm_period_seconds             | Evaluation period in seconds                                                    | `number`       | `300`               |    no    |
| **Dashboard**                    |                                                                                 |                |                     |          |
| enable_dashboard                 | Create a CloudWatch dashboard for WAF metrics                                   | `bool`         | `true`              |    no    |
| **Athena**                       |                                                                                 |                |                     |          |
| enable_athena                    | Create Athena workgroup, Glue DB/table, and results bucket                      | `bool`         | `true`              |    no    |
| athena_results_retention_days    | Days to retain Athena query results before auto-deletion                        | `number`       | `7`                 |    no    |
| athena_bytes_scanned_limit       | Max bytes per Athena query (queries exceeding this are cancelled)               | `number`       | `1073741824` (1 GB) |    no    |
| **Shared**                       |                                                                                 |                |                     |          |
| tags                             | Tags to apply to all resources                                                  | `map(string)`  | `{}`                |    no    |

## Outputs

| Name                  | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| sns_topic_arn         | ARN of the SNS topic for WAF alerts                            |
| s3_bucket_arn         | ARN of the S3 bucket for WAF full logs                         |
| s3_bucket_name        | Name of the S3 bucket for WAF full logs                        |
| dashboard_name        | CloudWatch dashboard name (empty when disabled)                |
| alarm_arns            | Map of alarm name to ARN for all WAF alarms                    |
| alarm_names           | List of CloudWatch alarm names                                 |
| athena_workgroup_name | Athena workgroup name (empty when disabled)                    |
| athena_database_name  | Glue database name (empty when disabled)                       |
| athena_table_name     | Glue table name (empty when disabled)                          |
| athena_results_bucket | S3 bucket for query results (empty when disabled)              |
| athena_query_context  | Ready-to-use context with db/table/workgroup + example queries |

## Important Notes

1. **Email Confirmation Required** — After `terraform apply`, each email address in `alert_emails` will receive a confirmation email from AWS SNS. Subscriptions are **pending** until confirmed. No alerts will be delivered until the recipient clicks the confirmation link.

2. **`app_name` Must Match** — The `app_name` variable must be identical to the one used in the `waf_standard` module. CloudWatch alarm dimensions reference WAF metric names derived from this value.

3. **S3 Bucket Naming** — The bucket name follows WAF logging convention: `aws-waf-logs-{app_name}-{scope}-s3`. S3 bucket names are globally unique — ensure no naming conflicts.

4. **Dashboard Cost** — CloudWatch dashboards cost $3/month per dashboard. Set `enable_dashboard = false` if not needed.

5. **Alarm Tuning** — Default thresholds are starting points. Monitor your baseline traffic and adjust thresholds to match your application's normal patterns to avoid alert fatigue.

6. **Athena Cost** — Athena charges $5/TB data scanned. Creating database/table/workgroup is free. WAF logs are typically small (1–50 MB/day) so queries cost fractions of a cent. The workgroup enforces a 1 GB scan limit by default to prevent unexpected costs.

7. **Athena Partition Projection** — The Glue table uses partition projection (`year/month/day/hour`), so partitions are computed on-the-fly. No need to run `MSCK REPAIR TABLE` or add partitions manually.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.6 |
| aws       | 6.0.0    |
