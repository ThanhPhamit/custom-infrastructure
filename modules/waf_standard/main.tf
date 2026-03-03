# ---------------------------------------------------------------------------
# Optional: IP set for allowlist rule
# ---------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "allowed_ips" {
  count = local.effective_enable_ip_allowlist ? 1 : 0

  name               = "${var.app_name}-${lower(var.scope)}-allowed-ips"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_addresses

  tags = merge({ Name = "${var.app_name}-allowed-ips" }, var.tags)
}

# ---------------------------------------------------------------------------
# Web ACL
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  name  = "${var.app_name}-${lower(var.scope)}-waf"
  scope = var.scope # "CLOUDFRONT" or "REGIONAL"

  default_action {
    allow {}
  }

  # ── Always-on ─────────────────────────────────────────────────────────────

  # Priority 1 │ Block IPs with known bad reputation (DDoS, botnets, scanners)
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 1

    dynamic "override_action" {
      for_each = [var.ip_reputation_action_mode]
      content {
        dynamic "none" {
          for_each = override_action.value == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = override_action.value == "count" ? [1] : []
          content {}
        }
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-IPReputation"
      sampled_requests_enabled   = true
    }
  }

  # Priority 50 │ Rate limiting – block HTTP floods per IP
  rule {
    name     = "RateLimitRule"
    priority = 50

    dynamic "action" {
      for_each = [var.rate_limit_action_mode]
      content {
        dynamic "block" {
          for_each = action.value == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = action.value == "count" ? [1] : []
          content {}
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = local.effective_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Priority 100 │ OWASP Top 10 (CRS) – SQLi, XSS, path traversal, etc.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 100

    dynamic "override_action" {
      for_each = [var.crs_action_mode]
      content {
        dynamic "none" {
          for_each = override_action.value == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = override_action.value == "count" ? [1] : []
          content {}
        }
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Allow large request bodies (e.g. file uploads); remove if not needed
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            allow {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ── Optional rules ────────────────────────────────────────────────────────

  # Priority 10 │ IP Allowlist – explicitly trust internal/partner IPs.
  #              Evaluated BEFORE rate-limit so trusted IPs are never blocked.
  dynamic "rule" {
    for_each = local.effective_enable_ip_allowlist ? [1] : []
    content {
      name     = "IPAllowlistRule"
      priority = 10

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-IPAllowlist"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 20 │ Geo-blocking – drop traffic from unwanted countries.
  dynamic "rule" {
    for_each = local.effective_enable_geo_block && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 20

      dynamic "action" {
        for_each = [var.geo_block_action_mode]
        content {
          dynamic "block" {
            for_each = action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-GeoBlock"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 30 │ Anonymous IP List – block VPNs, Tor exit nodes, proxies.
  dynamic "rule" {
    for_each = local.effective_enable_anonymous_ip_list ? [1] : []
    content {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 30

      dynamic "override_action" {
        for_each = [var.anonymous_ip_action_mode]
        content {
          dynamic "none" {
            for_each = override_action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = override_action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAnonymousIpList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-AnonymousIPList"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 60 │ Body size restriction – reject oversized payloads.
  dynamic "rule" {
    for_each = local.effective_enable_body_size_restriction ? [1] : []
    content {
      name     = "BodySizeRestrictionRule"
      priority = 60

      dynamic "action" {
        for_each = [var.body_size_action_mode]
        content {
          dynamic "block" {
            for_each = action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        size_constraint_statement {
          field_to_match {
            body {
              oversize_handling = "CONTINUE"
            }
          }
          comparison_operator = "GT"
          size                = var.max_body_size_bytes
          text_transformation {
            priority = 0
            type     = "NONE"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-BodySizeRestriction"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 70 │ SQL Injection – dedicated AWS managed SQLi rule set.
  #              Adds deeper coverage on top of CRS rule at priority 100.
  dynamic "rule" {
    for_each = local.effective_enable_sql_injection_protection ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 70

      dynamic "override_action" {
        for_each = [var.sql_injection_action_mode]
        content {
          dynamic "none" {
            for_each = override_action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = override_action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-SQLiRuleSet"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 80 │ Known Bad Inputs – Log4Shell, SSRF probes, Spring4Shell, etc.
  dynamic "rule" {
    for_each = local.effective_enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 80

      dynamic "override_action" {
        for_each = [var.known_bad_inputs_action_mode]
        content {
          dynamic "none" {
            for_each = override_action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = override_action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-KnownBadInputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 90 │ Bot Control – detect & block scrapers, crawlers, headless browsers.
  #              NOTE: this rule has an additional cost (~$10/month + per-request fee).
  dynamic "rule" {
    for_each = local.effective_enable_bot_control ? [1] : []
    content {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 90

      dynamic "override_action" {
        for_each = [var.bot_control_action_mode]
        content {
          dynamic "none" {
            for_each = override_action.value == "block" ? [1] : []
            content {}
          }
          dynamic "count" {
            for_each = override_action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"
          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = var.bot_control_inspection_level
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.app_name}-BotControl"
        sampled_requests_enabled   = true
      }
    }
  }

  tags = merge({ Name = "${var.app_name}-${lower(var.scope)}-waf" }, var.tags)

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-WAF-Main"
    sampled_requests_enabled   = true
  }
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# Log Group name MUST start with 'aws-waf-logs-'
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.app_name}-${lower(var.scope)}"
  retention_in_days = var.log_retention

  tags = merge({ Name = "${var.app_name}-waf-logs" }, var.tags)
}

# Resource policy – allows WAF service principal to write to CloudWatch
resource "aws_cloudwatch_log_resource_policy" "waf_logging_policy" {
  policy_document = data.aws_iam_policy_document.waf_logging_policy.json
  policy_name     = "aws-waf-logs-${var.app_name}-${lower(var.scope)}"
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  depends_on = [aws_cloudwatch_log_resource_policy.waf_logging_policy]
}
