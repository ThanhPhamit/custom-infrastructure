# AWS WAF Standard Terraform Module

Terraform module which creates an AWS WAFv2 Web ACL with security best practices. Supports both **Global (CloudFront)** and **Regional (ALB, API Gateway, AppSync, Cognito, App Runner)** deployments using a single module with **service-type presets**.

## Features

This module supports creating:

- **WAFv2 Web ACL** - With configurable scope (`CLOUDFRONT` or `REGIONAL`)
- **Service-Type Presets** - Pre-configured rule sets per target service (ALB, API Gateway, etc.)
- **Always-On Rules** - IP Reputation, Rate Limiting, OWASP Core Rule Set (CRS)
- **Optional Rules** - IP Allowlist, Geo-blocking, Anonymous IP, Body Size, SQLi, Known Bad Inputs, Bot Control
- **Override Support** - Every preset default can be overridden per-deployment

> **Logging & Monitoring** are handled by the companion `waf_monitoring` module. This module focuses purely on WAF rules.

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         service_type             │
                    │  (CLOUDFRONT / ALB / API_GATEWAY │
                    │   APPSYNC / COGNITO / APP_RUNNER │
                    │   CUSTOM)                        │
                    └───────────────┬─────────────────┘
                                    │ selects preset
                    ┌───────────────▼─────────────────┐
                    │        WAFv2 Web ACL             │
                    │                                  │
                    │  ┌─ Always-on ────────────────┐  │
                    │  │ P1   IP Reputation List    │  │
                    │  │ P50  Rate Limiting         │  │
                    │  │ P100 CRS / OWASP Top 10    │  │
                    │  └────────────────────────────┘  │
                    │                                  │
                    │  ┌─ Optional (preset/override) ┐ │
                    │  │ P10  IP Allowlist           │  │
                    │  │ P20  Geo-blocking           │  │
                    │  │ P30  Anonymous IP List      │  │
                    │  │ P60  Body Size Restriction  │  │
                    │  │ P70  SQL Injection (SQLi)   │  │
                    │  │ P80  Known Bad Inputs       │  │
                    │  │ P90  Bot Control ($)        │  │
                    │  └────────────────────────────┘  │
                    └─────────────────────────────────┘
                              │ web_acl_arn
                    ┌─────────▼───────────────────────┐
                    │      waf_monitoring module       │
                    │  CW Log Group + S3 + SNS Alerts  │
                    │  CW Alarms + Dashboard           │
                    └─────────────────────────────────┘
```

## Service-Type Presets

Choose a `service_type` and the module auto-enables the right rules. Set any `enable_*` variable explicitly to override.

| Rule                 | CLOUDFRONT     | ALB            | API_GATEWAY    | APPSYNC        | COGNITO        | APP_RUNNER     | CUSTOM         |
| -------------------- | -------------- | -------------- | -------------- | -------------- | -------------- | -------------- | -------------- |
| IP Reputation        | always         | always         | always         | always         | always         | always         | always         |
| Rate Limit (default) | 5000           | 2000           | 1000           | 1000           | 500            | 2000           | 2000           |
| CRS / OWASP Top 10   | always         | always         | always         | always         | always         | always         | always         |
| IP Allowlist †       | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) |
| Geo-blocking †       | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) | off (disabled) |
| Anonymous IP List    | **on**         | off            | off            | off            | **on**         | off            | off            |
| Body Size            | off            | **on**         | **on**         | off            | off            | **on**         | off            |
| SQL Injection        | off            | **on**         | **on**         | **on**         | off            | **on**         | off            |
| Known Bad Inputs     | **on**         | **on**         | **on**         | **on**         | off            | **on**         | off            |
| Bot Control ($)      | off            | off            | off            | off            | **on**         | off            | off            |

> **†** IP Allowlist and Geo-blocking are **always disabled by default** across all service types — they have no preset logic and must be explicitly enabled via `enable_ip_allowlist = true` or `enable_geo_block = true`.
>
> **Note:** Bot Control incurs additional AWS cost (~$10/month + per-request fee).

## Usage

### Example 1: CloudFront WAF (Global Edge)

CloudFront WAF **must** be deployed in `us-east-1`.

```terraform
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "waf_cloudfront" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "CLOUDFRONT"
  service_type = "CLOUDFRONT"

  providers = {
    aws = aws.us_east_1
  }

  # Action modes (block = enforce, count = monitor only)
  ip_reputation_action_mode    = "block"  # Always-on: known bad IPs
  rate_limit_action_mode       = "block"  # Always-on: HTTP flood protection
  crs_action_mode              = "block"  # Always-on: OWASP Top 10
  anonymous_ip_action_mode     = "count"  # Preset ON for CLOUDFRONT
  known_bad_inputs_action_mode = "count"  # Preset ON for CLOUDFRONT

  tags = local.tags
}

# Associate with CloudFront distribution
resource "aws_cloudfront_distribution" "main" {
  # ...
  web_acl_id = module.waf_cloudfront.web_acl_arn
  # ...
}
```

### Example 2: ALB WAF (Regional)

```terraform
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  service_type = "ALB"

  # Action modes (block = enforce, count = monitor only)
  ip_reputation_action_mode    = "block"  # Always-on: known bad IPs
  rate_limit_action_mode       = "block"  # Always-on: HTTP flood protection
  crs_action_mode              = "block"  # Always-on: OWASP Top 10
  body_size_action_mode        = "count"  # Preset ON for ALB
  sql_injection_action_mode    = "count"  # Preset ON for ALB
  known_bad_inputs_action_mode = "count"  # Preset ON for ALB

  tags = local.tags
}

# Associate with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = module.waf_alb.waf_arn
}
```

### Example 3: API Gateway with Geo-blocking

```terraform
module "waf_api" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-api"
  scope        = "REGIONAL"
  service_type = "API_GATEWAY"

  # Manually enable geo-blocking (not in preset)
  enable_geo_block  = true
  blocked_countries = ["CN", "RU", "KP"]

  # Override preset: disable body size restriction for this API
  enable_body_size_restriction = false

  # Action modes (block = enforce, count = monitor only)
  ip_reputation_action_mode    = "block"  # Always-on: known bad IPs
  rate_limit_action_mode       = "block"  # Always-on: HTTP flood protection
  crs_action_mode              = "block"  # Always-on: OWASP Top 10
  geo_block_action_mode        = "count"  # Manually enabled above
  sql_injection_action_mode    = "count"  # Preset ON for API_GATEWAY
  known_bad_inputs_action_mode = "count"  # Preset ON for API_GATEWAY

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = module.waf_api.waf_arn
}
```

### Example 4: Cognito User Pool (Auth Protection)

```terraform
module "waf_cognito" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-auth"
  scope        = "REGIONAL"
  service_type = "COGNITO"

  # IP allowlist for internal tools
  enable_ip_allowlist  = true
  allowed_ip_addresses = ["10.0.0.0/8", "172.16.0.0/12"]

  # Action modes (block = enforce, count = monitor only)
  ip_reputation_action_mode = "block"  # Always-on: known bad IPs
  rate_limit_action_mode    = "block"  # Always-on: HTTP flood protection
  crs_action_mode           = "block"  # Always-on: OWASP Top 10
  anonymous_ip_action_mode  = "count"  # Preset ON for COGNITO
  bot_control_action_mode   = "count"  # Preset ON for COGNITO ($)

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "cognito" {
  resource_arn = aws_cognito_user_pool.main.arn
  web_acl_arn  = module.waf_cognito.waf_arn
}
```

### Example 5: Custom (Full Manual Control)

```terraform
module "waf_custom" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-custom"
  scope        = "REGIONAL"
  service_type = "CUSTOM"

  rate_limit_override             = 500
  enable_sql_injection_protection = true
  enable_known_bad_inputs         = true
  enable_bot_control              = true
  bot_control_inspection_level    = "TARGETED"

  # Action modes (block = enforce, count = monitor only)
  ip_reputation_action_mode    = "block"  # Always-on: known bad IPs
  rate_limit_action_mode       = "block"  # Always-on: HTTP flood protection
  crs_action_mode              = "block"  # Always-on: OWASP Top 10
  sql_injection_action_mode    = "count"  # Manually enabled above
  known_bad_inputs_action_mode = "count"  # Manually enabled above
  bot_control_action_mode      = "count"  # Manually enabled above ($)

  tags = local.tags
}
```

## CloudFront + ALB: Defense in Depth

When CloudFront sits in front of an ALB, you need to decide how many WAF layers to deploy. The `CLOUDFRONT` preset alone does **not** enable SQLi or Body Size protection — those are app-level concerns.

### Approach 1: WAF on Both Layers (Recommended)

Best when the ALB is **public** or you want **defense in depth**. Each WAF handles the threats relevant to its layer.

```
User → CloudFront WAF (edge filtering) → ALB WAF (app protection) → Application
         ├─ IP Reputation                  ├─ IP Reputation
         ├─ Rate Limit (5000)              ├─ Rate Limit (2000)
         ├─ CRS / OWASP                    ├─ CRS / OWASP
         ├─ Anonymous IP List              ├─ SQL Injection
         └─ Known Bad Inputs               ├─ Body Size Restriction
                                           └─ Known Bad Inputs
```

```terraform
# Edge layer — filter DDoS, bots, bad IPs at CloudFront edge
module "waf_cloudfront" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "CLOUDFRONT"
  service_type = "CLOUDFRONT"
  providers    = { aws = aws.us_east_1 }

  # Action modes
  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"
  anonymous_ip_action_mode     = "count"  # Preset ON
  known_bad_inputs_action_mode = "count"  # Preset ON

  tags = local.tags
}

# App layer — filter SQLi, oversized payloads, protect backend
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  service_type = "ALB"

  # Action modes
  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"
  body_size_action_mode        = "count"  # Preset ON
  sql_injection_action_mode    = "count"  # Preset ON
  known_bad_inputs_action_mode = "count"  # Preset ON

  tags = local.tags
}

# Associate
resource "aws_cloudfront_distribution" "main" {
  # ...
  web_acl_id = module.waf_cloudfront.web_acl_arn
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = module.waf_alb.waf_arn
}
```

> **Cost:** ~$5–6/month extra for the second Web ACL. Negligible compared to the security benefit.

### Approach 2: CloudFront WAF Only + Override (Budget-Friendly)

Only viable when the ALB is **private** (Security Group restricted to [CloudFront managed prefix list](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html) only). Override the `CLOUDFRONT` preset to add app-level rules.

```
User → CloudFront WAF (edge + app filtering) → ALB (private, no WAF) → Application
         ├─ IP Reputation
         ├─ Rate Limit (5000)
         ├─ CRS / OWASP
         ├─ Anonymous IP List
         ├─ Known Bad Inputs
         ├─ SQL Injection       ← override
         └─ Body Size           ← override
```

```terraform
module "waf_cloudfront" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "CLOUDFRONT"
  service_type = "CLOUDFRONT"
  providers    = { aws = aws.us_east_1 }

  # Override: add app-level protection at the edge
  enable_sql_injection_protection = true
  enable_body_size_restriction    = true

  # Action modes
  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"
  anonymous_ip_action_mode     = "count"  # Preset ON
  known_bad_inputs_action_mode = "count"  # Preset ON
  sql_injection_action_mode    = "count"  # Override enabled above
  body_size_action_mode        = "count"  # Override enabled above

  tags = local.tags
}
```

> **Warning:** If anyone can reach the ALB directly (bypassing CloudFront), there is **zero WAF protection** on the backend. Always verify your ALB Security Group only allows the CloudFront prefix list.

### Which Approach to Choose?

| Scenario                                     | Recommendation        |
| -------------------------------------------- | --------------------- |
| ALB is **public** (reachable from internet)  | **Approach 1** (both) |
| ALB is **private** (SG locked to CloudFront) | Approach 2 is OK      |
| Compliance / audit requirements              | **Approach 1** (both) |
| Minimal budget, simple app                   | Approach 2 + lock SG  |

## How Association Works

| Service         | Scope        | Association Method                                          |
| --------------- | ------------ | ----------------------------------------------------------- |
| **CloudFront**  | `CLOUDFRONT` | Set `web_acl_id` on `aws_cloudfront_distribution`           |
| **ALB**         | `REGIONAL`   | `aws_wafv2_web_acl_association` with ALB ARN                |
| **API Gateway** | `REGIONAL`   | `aws_wafv2_web_acl_association` with API stage ARN          |
| **AppSync**     | `REGIONAL`   | `aws_wafv2_web_acl_association` with AppSync API ARN        |
| **Cognito**     | `REGIONAL`   | `aws_wafv2_web_acl_association` with Cognito User Pool ARN  |
| **App Runner**  | `REGIONAL`   | `aws_wafv2_web_acl_association` with App Runner service ARN |

> **Important:** CloudFront WAF configurations **always** live in `us-east-1`, regardless of your application region.

## Rule Action Modes: `block` vs `count`

Every rule has a `*_action_mode` variable to toggle between **enforcing** and **monitoring**:

| Mode      | Behavior                                  | Use When                           |
| --------- | ----------------------------------------- | ---------------------------------- |
| `"block"` | Actively block/drop matching requests     | Production (confirmed safe)        |
| `"count"` | Log & count only — request passes through | Testing / dry-run / initial deploy |

### Recommended Rollout Workflow

```
  Week 1-2: Deploy all rules in "count" mode
       │    └─ Monitor CloudWatch metrics for false positives
       ▼
  Week 3:   Switch critical rules to "block"
       │    └─ ip_reputation, rate_limit, crs (OWASP)
       ▼
  Week 4+:  Switch remaining rules to "block" one by one
            └─ geo_block, anonymous_ip, body_size, sql_injection,
               known_bad_inputs, bot_control
```

### Default Action Modes

| Rule                   | Variable                       | Default   | Reason                                |
| ---------------------- | ------------------------------ | --------- | ------------------------------------- |
| IP Reputation (P1)     | `ip_reputation_action_mode`    | `"block"` | Critical — blocks known bad IPs       |
| Rate Limit (P50)       | `rate_limit_action_mode`       | `"block"` | Critical — prevents HTTP floods       |
| CRS / OWASP (P100)     | `crs_action_mode`              | `"block"` | Critical — OWASP Top 10 protection    |
| Geo-blocking (P20)     | `geo_block_action_mode`        | `"count"` | Test first — may block legit users    |
| Anonymous IP (P30)     | `anonymous_ip_action_mode`     | `"count"` | Test first — may block VPN users      |
| Body Size (P60)        | `body_size_action_mode`        | `"count"` | Test first — tune max_body_size       |
| SQL Injection (P70)    | `sql_injection_action_mode`    | `"count"` | Test first — possible false positives |
| Known Bad Inputs (P80) | `known_bad_inputs_action_mode` | `"count"` | Test first — review logs first        |
| Bot Control (P90)      | `bot_control_action_mode`      | `"count"` | Test first — may block good bots      |

> **Note:** IP Allowlist (P10) always uses `allow` action — it's not affected by action modes.

### Example: Full Count Mode (Safe Initial Deploy)

```terraform
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "staging-myapp"
  scope        = "REGIONAL"
  service_type = "ALB"

  # All rules in monitoring mode — nothing is blocked
  ip_reputation_action_mode    = "count"
  rate_limit_action_mode       = "count"
  crs_action_mode              = "count"
  sql_injection_action_mode    = "count"
  known_bad_inputs_action_mode = "count"
  body_size_action_mode        = "count"

  tags = local.tags
}
```

### Example: Gradual Enforcement (After Testing)

```terraform
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "prod-myapp"
  scope        = "REGIONAL"
  service_type = "ALB"

  # Critical rules enforcing
  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"

  # Still testing these — will switch to "block" after review
  sql_injection_action_mode    = "count"
  known_bad_inputs_action_mode = "count"
  body_size_action_mode        = "count"

  tags = local.tags
}
```

## Advanced: Rule Action Overrides (Fine-Grained Sub-Rule Control)

For complex deployments, you may want a managed rule group in `"block"` mode overall, but specific sub-rules in `"count"` mode to reduce false positives. The `sqli_count_override_rules` variable enables this surgical control for SQL Injection detection.

### When to Use Rule Action Overrides

SQL Injection detection has different false positive rates depending on **where** the attack pattern is found:

| Location       | Attack Surface                        | False Positive Rate | Recommendation            |
| -------------- | ------------------------------------- | ------------------- | ------------------------- |
| **Body**       | Form data, JSON                       | Low (~1%)           | **BLOCK**                 |
| **Cookies**    | Session params                        | Low (~1%)           | **BLOCK**                 |
| **Headers**    | Content-Type                          | Low (~2%)           | **BLOCK**                 |
| **Query Args** | Product IDs, search terms, pagination | High (~80%)         | **COUNT** (if e-commerce) |

In e-commerce applications, query arguments frequently contain legitimate numbers (like product IDs or page numbers) that can trigger SQLi patterns. Blocking these causes customer friction. By overriding specific sub-rules to `"count"` mode, you allow legitimate queries through while still blocking true attacks in more dangerous locations.

### Available SQLi Sub-Rules

The `AWSManagedRulesSQLiRuleSet` contains several sub-rules that can be individually overridden:

- `SQLi_BODY` — SQL injection in request body (forms, JSON)
- `SQLi_COOKIE` — SQL injection in cookies (session hijacking)
- `SQLi_QUERYARGUMENTS` — **Most false positives** for e-commerce
- `SQLi_HEADERS` — SQL injection in HTTP headers
- `SQLiExtendedPatterns_BODY` — Extended/obfuscated SQLi patterns in body
- `SQLiExtendedPatterns_QUERYARGUMENTS` — **High false positives** for e-commerce
- `SQLiExtendedPatterns_HEADERS` — Extended SQLi patterns in headers

### Real-World Example: Welfan E-Commerce

A real WAF analysis on Welfan's e-commerce traffic (3-day sample) revealed:

- **26 SQL Injection hits detected** in query arguments
- **All 26 hits from one legitimate customer IP** (`153.142.29.193`)
- **All hits on legitimate product pages** (e.g., `/product.aspx?id=5247682`, `/search.aspx?q=printer+cartridge`)
- **0 SQLi hits in body/cookies** (true attack surface)

**Classification:**

- 25 hits on `SQLi_QUERYARGUMENTS` (false positive)
- 1 hit on `SQLiExtendedPatterns_QUERYARGUMENTS` (false positive)
- These product IDs and search terms don't indicate a security risk; typical e-commerce data

**Decision:** Block SQLi overall (`sql_injection_action_mode = "block"`), but override query argument sub-rules to `"count"` mode. This lets the legitimate customer browse freely while still blocking:

- Actual SQLi injection attempts in request body (form data)
- Session hijacking attempts via cookie injection
- Header-based injection attacks

### Configuration: sqli_count_override_rules

```terraform
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-store"
  scope        = "REGIONAL"
  service_type = "ALB"

  # SQLi rule enforces overall, but with targeted sub-rule overrides
  sql_injection_action_mode = "block"

  # Override: Count (don't block) SQLi in query arguments to reduce false positives
  # These sub-rule names are from AWSManagedRulesSQLiRuleSet
  sqli_count_override_rules = [
    "SQLi_QUERYARGUMENTS",
    "SQLiExtendedPatterns_QUERYARGUMENTS",
  ]

  # All other action modes
  ip_reputation_action_mode    = "block"
  rate_limit_action_mode       = "block"
  crs_action_mode              = "block"
  body_size_action_mode        = "count"
  known_bad_inputs_action_mode = "count"

  tags = local.tags
}
```

**How it works:**

- Requests with SQLi patterns in **body/cookie/headers** → **BLOCKED** (action = block)
- Requests with SQLi patterns in **query arguments** → **COUNTED, NOT BLOCKED** (action = count)
- CloudWatch alarms trigger only on blocked requests (body/cookies), not the false positives

### Monitoring Rule Action Overrides

After deploying with `sqli_count_override_rules`, check CloudWatch:

1. **SQL Injection – Blocked** alarm (on BlockedRequests metric)
   - True positives: rare (real SQLi attempts are usually in body/cookies)
   - Adjust further if blocked query arg patterns appear

2. **SQL Injection – Counted** alarm (on CountedRequests metric)
   - High activity: expected (legitimate product IDs, search terms)
   - Review logs if you see suspicious patterns outside known query params

### Migration Path

```
Phase 1: sql_injection_action_mode = "count"
         └─ Baseline: capture all SQLi hits

Phase 2: sql_injection_action_mode = "block" + sqli_count_override_rules = ["SQLi_QUERYARGUMENTS", "SQLiExtendedPatterns_QUERYARGUMENTS"]
         └─ Production: block true SQLi, allow legitimate query args

Phase 3 (optional): Remove overrides → sql_injection_action_mode = "block" + sqli_count_override_rules = []
                    └─ Strict mode: block all SQLi (for non-user-input query params)
```

## Rule Priority Map

| Priority | Rule                         | Type               | Status    | Default Action |
| -------- | ---------------------------- | ------------------ | --------- | -------------- |
| 1        | IP Reputation List           | AWS Managed        | Always on | `block`        |
| 10       | IP Allowlist                 | Custom (IP Set)    | Optional  | `allow`        |
| 20       | Geo-blocking                 | Custom (Geo Match) | Optional  | `count`        |
| 30       | Anonymous IP List            | AWS Managed        | Preset    | `count`        |
| 50       | Rate Limiting                | Custom (Rate)      | Always on | `block`        |
| 60       | Body Size Restriction        | Custom (Size)      | Preset    | `count`        |
| 70       | SQL Injection (SQLi)         | AWS Managed        | Preset    | `count`        |
| 80       | Known Bad Inputs             | AWS Managed        | Preset    | `count`        |
| 90       | Bot Control                  | AWS Managed ($)    | Preset    | `count`        |
| 100      | Core Rule Set (OWASP Top 10) | AWS Managed        | Always on | `block`        |

> Priorities are spaced to allow inserting additional custom rules in between if needed.

## Override Behavior

Each optional rule variable defaults to `null`, meaning "use the service_type preset":

```terraform
# Uses ALB preset defaults (SQLi=on, BodySize=on, KnownBadInputs=on)
module "waf" {
  service_type = "ALB"
}

# Same ALB preset but override: turn OFF body size, turn ON bot control
module "waf" {
  service_type                 = "ALB"
  enable_body_size_restriction = false  # override preset
  enable_bot_control           = true   # override preset
}
```

- `null` → use `service_type` preset (default for all optional rules)
- `true` → force enable, regardless of preset
- `false` → force disable, regardless of preset
- `enable_ip_allowlist` and `enable_geo_block` are always user-controlled (no preset)

## Inputs

| Name                            | Description                                                  | Type           | Default    | Required |
| ------------------------------- | ------------------------------------------------------------ | -------------- | ---------- | :------: |
| app_name                        | Application name for resource naming prefix                  | `string`       | n/a        |   yes    |
| scope                           | WAF scope: `CLOUDFRONT` or `REGIONAL`                        | `string`       | n/a        |   yes    |
| service_type                    | Target service preset (see Presets table)                    | `string`       | `"CUSTOM"` |    no    |
| rate_limit_override             | Override preset rate limit (requests/5min/IP). null = preset | `number`       | `null`     |    no    |
| **Action Mode Variables**       |                                                              |                |            |          |
| ip_reputation_action_mode       | IP Reputation (P1): `"block"` or `"count"`                   | `string`       | `"block"`  |    no    |
| rate_limit_action_mode          | Rate Limit (P50): `"block"` or `"count"`                     | `string`       | `"block"`  |    no    |
| crs_action_mode                 | CRS / OWASP (P100): `"block"` or `"count"`                   | `string`       | `"block"`  |    no    |
| geo_block_action_mode           | Geo-blocking (P20): `"block"` or `"count"`                   | `string`       | `"count"`  |    no    |
| anonymous_ip_action_mode        | Anonymous IP (P30): `"block"` or `"count"`                   | `string`       | `"count"`  |    no    |
| body_size_action_mode           | Body Size (P60): `"block"` or `"count"`                      | `string`       | `"count"`  |    no    |
| sql_injection_action_mode       | SQL Injection (P70): `"block"` or `"count"`                  | `string`       | `"count"`  |    no    |
| known_bad_inputs_action_mode    | Known Bad Inputs (P80): `"block"` or `"count"`               | `string`       | `"count"`  |    no    |
| bot_control_action_mode         | Bot Control (P90): `"block"` or `"count"`                    | `string`       | `"count"`  |    no    |
| **Advanced Rule Tuning**        |                                                              |                |            |          |
| sqli_count_override_rules       | SQLi sub-rules to override to COUNT (reduce false positives) | `list(string)` | `[]`       |    no    |
| **Rule Enable/Disable**         |                                                              |                |            |          |
| enable_ip_allowlist             | Enable IP allowlist rule                                     | `bool`         | `false`    |    no    |
| allowed_ip_addresses            | IPv4 CIDRs to allowlist                                      | `list(string)` | `[]`       |    no    |
| enable_geo_block                | Enable geo-blocking rule                                     | `bool`         | `false`    |    no    |
| blocked_countries               | ISO 3166 country codes to block                              | `list(string)` | `[]`       |    no    |
| enable_anonymous_ip_list        | Enable Anonymous IP List rule. null = preset                 | `bool`         | `null`     |    no    |
| enable_body_size_restriction    | Enable body size restriction rule. null = preset             | `bool`         | `null`     |    no    |
| max_body_size_bytes             | Max body size in bytes                                       | `number`       | `8192`     |    no    |
| enable_sql_injection_protection | Enable SQLi rule set. null = preset                          | `bool`         | `null`     |    no    |
| enable_known_bad_inputs         | Enable Known Bad Inputs rule set. null = preset              | `bool`         | `null`     |    no    |
| enable_bot_control              | Enable Bot Control rule set (extra cost). null = preset      | `bool`         | `null`     |    no    |
| bot_control_inspection_level    | Bot Control level: `COMMON` or `TARGETED`                    | `string`       | `"COMMON"` |    no    |
| tags                            | Tags to apply to all resources                               | `map(string)`  | `{}`       |    no    |

## Outputs

| Name                 | Description                                                                                     |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| web_acl_arn          | ARN of the WAF Web ACL                                                                          |
| web_acl_id           | ID of the WAF Web ACL (for CloudFront `web_acl_id`)                                             |
| waf_arn              | ARN alias (for `aws_wafv2_web_acl_association`)                                                 |
| ip_set_arn           | ARN of IP allowlist set (empty string when disabled)                                            |
| service_type         | The service_type preset used                                                                    |
| effective_rate_limit | Resolved rate limit (after preset/override resolution)                                          |
| web_acl_metric_name  | CloudWatch metric name for use in monitoring                                                    |
| active_rules         | Map of rule key → `{metric_name, action_mode}` for all enabled rules (pass to `waf_monitoring`) |

## AWS Managed Rules Reference

| Rule Group             | What It Protects Against                                   | Cost     |
| ---------------------- | ---------------------------------------------------------- | -------- |
| AmazonIpReputationList | Known bad IPs, botnets, DDoS sources                       | Free     |
| CommonRuleSet (CRS)    | OWASP Top 10: XSS, path traversal, LFI, RFI                | Free     |
| AnonymousIpList        | VPNs, Tor, hosting providers, proxies                      | Free     |
| SQLiRuleSet            | SQL injection patterns                                     | Free     |
| KnownBadInputsRuleSet  | Log4Shell, Spring4Shell, SSRF probes                       | Free     |
| BotControlRuleSet      | Scrapers, crawlers, headless browsers, credential stuffing | **Paid** |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.6 |
| aws       | 6.0.0    |

## Notes

1. **CloudFront WAF** must always be created in `us-east-1` — pass a `us-east-1` provider alias.
2. **Regional WAF** must be in the same region as the target resource (ALB, API Gateway, etc.).
3. **Bot Control** has additional AWS costs (~$10/month + $1/million requests). Only enabled by default in `COGNITO` preset.
4. **Rate Limit** is evaluated per IP over a 5-minute sliding window.
5. **CRS SizeRestrictions_BODY** is overridden to `allow` by default to support file uploads. Remove the override in `main.tf` if you want strict body size enforcement via CRS.
6. **Logging & Monitoring** are handled by the separate `waf_monitoring` module. Pass `web_acl_arn` from this module to `waf_monitoring` to connect them.
