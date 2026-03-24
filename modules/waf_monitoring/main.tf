data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # The CloudWatch Metric 'WebACL' dimension must match the actual Name of the WebACL, not its visibility metric_name.
  waf_acl_name = "${var.app_name}-${lower(var.scope)}-waf"
  region       = data.aws_region.current.id
  account_id   = data.aws_caller_identity.current.account_id
  bucket_name  = "aws-waf-logs-${var.app_name}-${lower(var.scope)}-s3"

  # Human-readable labels for dashboard display
  rule_labels = {
    ip_reputation    = "IP Reputation"
    rate_limit       = "Rate Limit"
    crs              = "CRS/OWASP"
    ip_allowlist     = "IP Allowlist"
    geo_block        = "Geo Block"
    anonymous_ip     = "Anonymous IP"
    body_size        = "Body Size"
    sql_injection    = "SQL Injection"
    known_bad_inputs = "Known Bad Inputs"
    bot_control      = "Bot Control"
  }

  # Monitorable rules: exclude ip_allowlist (it uses Allow action, not Block/Count)
  monitorable_rules = { for k, v in var.active_rules : k => v if k != "ip_allowlist" }

  # Smart alarms: block mode → BlockedRequests alarm, count mode → CountedRequests alarm
  rule_alarms = {
    for key, rule in local.monitorable_rules : "${key}-${rule.action_mode == "block" ? "blocked" : "counted"}" => {
      metric = rule.action_mode == "block" ? "BlockedRequests" : "CountedRequests"
      rule   = rule.metric_name
      threshold = rule.action_mode == "block" ? (
        key == "rate_limit" ? var.alarm_rate_limit_threshold : var.alarm_blocked_requests_threshold
      ) : var.alarm_counted_requests_threshold
      desc = rule.action_mode == "block" ? (
        "High blocked requests from ${lookup(local.rule_labels, key, key)} rule"
        ) : (
        "High counted requests from ${lookup(local.rule_labels, key, key)} rule - review for enforcement"
      )
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# WAF Logging Configuration (connects Web ACL → S3)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [
    aws_s3_bucket.waf_logs.arn,
  ]
  resource_arn = var.web_acl_arn

  depends_on = [aws_s3_bucket_policy.waf_logs]
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket for WAF Full Logs
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "waf_logs" {
  bucket = local.bucket_name
  tags   = merge({ Name = local.bucket_name }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "waf_logs" {
  bucket                  = aws_s3_bucket.waf_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "waf-log-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.s3_transition_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_transition_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  policy = data.aws_iam_policy_document.s3_waf_logs.json
}

data "aws_iam_policy_document" "s3_waf_logs" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.waf_logs.arn}/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.waf_logs.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "waf_rules" {
  for_each = local.rule_alarms

  alarm_name          = "${var.app_name}-waf-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = each.value.metric
  namespace           = "AWS/WAFV2"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = each.value.threshold
  alarm_description   = each.value.desc
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  dimensions = {
    WebACL = local.waf_acl_name
    Rule   = each.value.rule
    Region = local.region
  }

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Dashboard
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "waf" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.app_name}-waf-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      # ── Row 1: Summary cards for always-on rules ───────────────────────────
      [for i, key in ["ip_reputation", "rate_limit", "crs"] :
        {
          type   = "metric"
          x      = i * 8
          y      = 0
          width  = 8
          height = 4
          properties = {
            title   = "Blocked (${lookup(local.rule_labels, key, key)})"
            region  = local.region
            stat    = "Sum"
            period  = 300
            view    = "singleValue"
            metrics = [["AWS/WAFV2", "BlockedRequests", "WebACL", local.waf_acl_name, "Rule", var.active_rules[key].metric_name, "Region", local.region]]
          }
        } if contains(keys(var.active_rules), key)
      ],

      # ── Row 2: Blocked Requests by Rule (timeline) ────────────────────────
      [{
        type   = "metric"
        x      = 0
        y      = 4
        width  = 24
        height = 6
        properties = {
          title   = "Blocked Requests by Rule"
          region  = local.region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          stacked = false
          metrics = [for key, rule in local.monitorable_rules :
            ["AWS/WAFV2", "BlockedRequests", "WebACL", local.waf_acl_name, "Rule", rule.metric_name, "Region", local.region, { label = lookup(local.rule_labels, key, key) }]
          ]
        }
      }],

      # ── Row 3: Counted Requests by Rule (monitor mode) ────────────────────
      [{
        type   = "metric"
        x      = 0
        y      = 10
        width  = 24
        height = 6
        properties = {
          title   = "Counted Requests by Rule (Monitor Mode)"
          region  = local.region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          stacked = false
          metrics = [for key, rule in local.monitorable_rules :
            ["AWS/WAFV2", "CountedRequests", "WebACL", local.waf_acl_name, "Rule", rule.metric_name, "Region", local.region, { label = lookup(local.rule_labels, key, key) }]
          ]
        }
      }],

      # ── Row 4: Allowed Requests (overall traffic) ─────────────────────────
      [{
        type   = "metric"
        x      = 0
        y      = 16
        width  = 24
        height = 6
        properties = {
          title   = "Allowed Requests (Total Traffic)"
          region  = local.region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", local.waf_acl_name, "Rule", "${var.app_name}-WAF-Main", "Region", local.region, { label = "Total Allowed" }]
          ]
        }
      }]
    )
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Athena: S3 Results Bucket + Workgroup + Glue Database & Table
# ─────────────────────────────────────────────────────────────────────────────

# S3 bucket for Athena query results (auto-cleanup after 7 days)
resource "aws_s3_bucket" "athena_results" {
  count  = var.enable_athena ? 1 : 0
  bucket = "${var.app_name}-waf-athena-results-${lower(var.scope)}"
  tags   = merge({ Name = "${var.app_name}-waf-athena-results" }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  count                   = var.enable_athena ? 1 : 0
  bucket                  = aws_s3_bucket.athena_results[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  count  = var.enable_athena ? 1 : 0
  bucket = aws_s3_bucket.athena_results[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  count  = var.enable_athena ? 1 : 0
  bucket = aws_s3_bucket.athena_results[0].id

  rule {
    id     = "cleanup-query-results"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.athena_results_retention_days
    }
  }
}

# Athena Workgroup with cost control
resource "aws_athena_workgroup" "waf" {
  count = var.enable_athena ? 1 : 0
  name  = "${var.app_name}-waf-logs"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results[0].id}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    bytes_scanned_cutoff_per_query = var.athena_bytes_scanned_limit
  }

  tags = merge({ Name = "${var.app_name}-waf-logs" }, var.tags)
}

# Glue Database
resource "aws_glue_catalog_database" "waf" {
  count = var.enable_athena ? 1 : 0
  name  = replace("${var.app_name}_waf_logs", "-", "_")
}

# Glue Table with WAF log schema (matches AWS WAF JSON log format)
resource "aws_glue_catalog_table" "waf_logs" {
  count         = var.enable_athena ? 1 : 0
  database_name = aws_glue_catalog_database.waf[0].name
  name          = "waf_logs"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "json"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2024,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "0,23"
    "projection.hour.digits"    = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.waf_logs.id}/AWSLogs/${local.account_id}/WAFLogs/${local.region}/${var.app_name}-regional-waf/$${year}/$${month}/$${day}/$${hour}/"
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }

  partition_keys {
    name = "day"
    type = "int"
  }

  partition_keys {
    name = "hour"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.waf_logs.id}/AWSLogs/${local.account_id}/WAFLogs/${local.region}/${var.app_name}-regional-waf/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = "1"
        "case.insensitive"     = "true"
      }
    }

    columns {
      name = "timestamp"
      type = "bigint"
    }

    columns {
      name = "formatversion"
      type = "int"
    }

    columns {
      name = "webaclid"
      type = "string"
    }

    columns {
      name = "terminatingruleid"
      type = "string"
    }

    columns {
      name = "terminatingruletype"
      type = "string"
    }

    columns {
      name = "action"
      type = "string"
    }

    columns {
      name = "terminatingrulematchdetails"
      type = "array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>"
    }

    columns {
      name = "httpsourcename"
      type = "string"
    }

    columns {
      name = "httpsourceid"
      type = "string"
    }

    columns {
      name = "rulegrouplist"
      type = "array<struct<rulegroupid:string,terminatingrule:struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>>,nonterminatingmatchingrules:array<struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>>>,excludedrules:string>>"
    }

    columns {
      name = "ratebasedrulelist"
      type = "array<struct<ratebasedruleid:string,limitkey:string,maxrateallowed:int>>"
    }

    columns {
      name = "nonterminatingmatchingrules"
      type = "array<struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,sensitivitylevel:string,location:string,matcheddata:array<string>>>>>"
    }

    columns {
      name = "requestheadersinserted"
      type = "array<struct<name:string,value:string>>"
    }

    columns {
      name = "responsecodesent"
      type = "int"
    }

    columns {
      name = "httprequest"
      type = "struct<clientip:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpversion:string,httpmethod:string,requestid:string>"
    }

    columns {
      name = "labels"
      type = "array<struct<name:string>>"
    }
  }
}
