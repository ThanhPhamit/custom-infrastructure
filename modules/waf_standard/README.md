# AWS WAF Standard Terraform Module

Terraform module which creates an AWS WAFv2 Web ACL with security best practices. Supports both **Global (CloudFront)** and **Regional (ALB, API Gateway, AppSync, Cognito, App Runner)** deployments using a single module with **service-type presets**.

## Features

This module supports creating:

- **WAFv2 Web ACL** - With configurable scope (`CLOUDFRONT` or `REGIONAL`)
- **Service-Type Presets** - Pre-configured rule sets per target service (ALB, API Gateway, etc.)
- **Always-On Rules** - IP Reputation, Rate Limiting, OWASP Core Rule Set (CRS)
- **Optional Rules** - IP Allowlist, Geo-blocking, Anonymous IP, Body Size, SQLi, Known Bad Inputs, Bot Control
- **CloudWatch Logging** - Automatic WAF log group with configurable retention
- **Override Support** - Every preset default can be overridden per-deployment

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
                    └───────────────┬─────────────────┘
                                    │
                    ┌───────────────▼─────────────────┐
                    │    CloudWatch Log Group          │
                    │    aws-waf-logs-{app}-{scope}    │
                    └─────────────────────────────────┘
```

## Service-Type Presets

Choose a `service_type` and the module auto-enables the right rules. Set any `enable_*` variable explicitly to override.

| Rule                 | CLOUDFRONT | ALB    | API_GATEWAY | APPSYNC | COGNITO | APP_RUNNER | CUSTOM |
| -------------------- | ---------- | ------ | ----------- | ------- | ------- | ---------- | ------ |
| IP Reputation        | always     | always | always      | always  | always  | always     | always |
| Rate Limit (default) | 5000       | 2000   | 1000        | 1000    | 500     | 2000       | 2000   |
| CRS / OWASP Top 10   | always     | always | always      | always  | always  | always     | always |
| Anonymous IP List    | **on**     | off    | off         | off     | **on**  | off        | off    |
| Body Size            | off        | **on** | **on**      | off     | off     | **on**     | off    |
| SQL Injection        | off        | **on** | **on**      | **on**  | off     | **on**     | off    |
| Known Bad Inputs     | **on**     | **on** | **on**      | **on**  | off     | **on**     | off    |
| Bot Control ($)      | off        | off    | off         | off     | **on**  | off        | off    |

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
  tags         = local.tags
}

# App layer — filter SQLi, oversized payloads, protect backend
module "waf_alb" {
  source       = "../../modules/waf_standard"
  app_name     = "${var.environment}-${var.app_name}"
  scope        = "REGIONAL"
  service_type = "ALB"
  tags         = local.tags
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

## Rule Priority Map

| Priority | Rule                         | Type               | Status    |
| -------- | ---------------------------- | ------------------ | --------- |
| 1        | IP Reputation List           | AWS Managed        | Always on |
| 10       | IP Allowlist                 | Custom (IP Set)    | Optional  |
| 20       | Geo-blocking                 | Custom (Geo Match) | Optional  |
| 30       | Anonymous IP List            | AWS Managed        | Preset    |
| 50       | Rate Limiting                | Custom (Rate)      | Always on |
| 60       | Body Size Restriction        | Custom (Size)      | Preset    |
| 70       | SQL Injection (SQLi)         | AWS Managed        | Preset    |
| 80       | Known Bad Inputs             | AWS Managed        | Preset    |
| 90       | Bot Control                  | AWS Managed ($)    | Preset    |
| 100      | Core Rule Set (OWASP Top 10) | AWS Managed        | Always on |

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
| log_retention                   | CloudWatch log retention in days                             | `number`       | `7`        |    no    |
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

| Name                 | Description                                            |
| -------------------- | ------------------------------------------------------ |
| web_acl_arn          | ARN of the WAF Web ACL                                 |
| web_acl_id           | ID of the WAF Web ACL (for CloudFront `web_acl_id`)    |
| waf_arn              | ARN alias (for `aws_wafv2_web_acl_association`)        |
| log_group_name       | CloudWatch log group name for WAF logs                 |
| ip_set_arn           | ARN of IP allowlist set (empty string when disabled)   |
| service_type         | The service_type preset used                           |
| effective_rate_limit | Resolved rate limit (after preset/override resolution) |

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
6. **WAF Logs** are written to CloudWatch with the required `aws-waf-logs-` prefix.

## License

Apache 2 Licensed. See LICENSE for full details.
