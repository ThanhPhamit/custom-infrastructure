# ---------------------------------------------------------------------------
# Service-type presets
# ---------------------------------------------------------------------------
# Each service type ships with recommended rule defaults. Users can still
# override any individual enable_* variable — explicit overrides always win.
#
# "opt" in the table below means the preset leaves it off, but you can turn
# it on manually.  See variables.tf for the full list of flags.
#
# ┌──────────────────────┬────────────┬─────┬─────────────┬─────────┬─────────┬────────────┐
# │ Rule                 │ CloudFront │ ALB │ API Gateway │ AppSync │ Cognito │ App Runner │
# ├──────────────────────┼────────────┼─────┼─────────────┼─────────┼─────────┼────────────┤
# │ IP Reputation        │ always     │ always │ always   │ always  │ always  │ always     │
# │ Rate Limit           │ always     │ always │ always   │ always  │ always  │ always     │
# │ CRS (OWASP)          │ always     │ always │ always   │ always  │ always  │ always     │
# │ Anonymous IP List    │ ✓          │ –   │ –           │ –       │ ✓       │ –          │
# │ Body Size            │ –          │ ✓   │ ✓           │ –       │ –       │ ✓          │
# │ SQL Injection        │ –          │ ✓   │ ✓           │ ✓       │ –       │ ✓          │
# │ Known Bad Inputs     │ ✓          │ ✓   │ ✓           │ ✓       │ –       │ ✓          │
# │ Bot Control ($)      │ –          │ –   │ –           │ –       │ ✓       │ –          │
# └──────────────────────┴────────────┴─────┴─────────────┴─────────┴─────────┴────────────┘

locals {
  # Preset defaults per service type
  presets = {
    CLOUDFRONT = {
      rate_limit                      = 5000 # Higher for edge traffic
      enable_anonymous_ip_list        = true # Block VPN/Tor at the edge
      enable_body_size_restriction    = false
      enable_sql_injection_protection = false
      enable_known_bad_inputs         = true  # Log4Shell, SSRF
      enable_bot_control              = false # Opt-in (extra cost)
    }
    ALB = {
      rate_limit                      = 2000
      enable_anonymous_ip_list        = false
      enable_body_size_restriction    = true # Protect backend from oversized payloads
      enable_sql_injection_protection = true # Web apps typically have DB
      enable_known_bad_inputs         = true
      enable_bot_control              = false
    }
    API_GATEWAY = {
      rate_limit                      = 1000 # APIs need stricter rate limiting
      enable_anonymous_ip_list        = false
      enable_body_size_restriction    = true
      enable_sql_injection_protection = true
      enable_known_bad_inputs         = true
      enable_bot_control              = false
    }
    APPSYNC = {
      rate_limit                      = 1000
      enable_anonymous_ip_list        = false
      enable_body_size_restriction    = false # GraphQL bodies vary a lot
      enable_sql_injection_protection = true  # Injection via GraphQL variables
      enable_known_bad_inputs         = true
      enable_bot_control              = false
    }
    COGNITO = {
      rate_limit                      = 500  # Strict — login/signup endpoints
      enable_anonymous_ip_list        = true # Block VPN/Tor from auth
      enable_body_size_restriction    = false
      enable_sql_injection_protection = false
      enable_known_bad_inputs         = false
      enable_bot_control              = true # Prevent credential stuffing
    }
    APP_RUNNER = {
      rate_limit                      = 2000
      enable_anonymous_ip_list        = false
      enable_body_size_restriction    = true
      enable_sql_injection_protection = true
      enable_known_bad_inputs         = true
      enable_bot_control              = false
    }
    CUSTOM = {
      rate_limit                      = 2000
      enable_anonymous_ip_list        = false
      enable_body_size_restriction    = false
      enable_sql_injection_protection = false
      enable_known_bad_inputs         = false
      enable_bot_control              = false
    }
  }

  # Resolve the active preset
  preset = local.presets[var.service_type]

  # Merge logic: explicit user value wins, otherwise use preset default.
  # "null" means "use the preset" — any non-null user value is an override.
  effective_rate_limit                      = coalesce(var.rate_limit_override, local.preset.rate_limit)
  effective_enable_anonymous_ip_list        = var.enable_anonymous_ip_list != null ? var.enable_anonymous_ip_list : local.preset.enable_anonymous_ip_list
  effective_enable_body_size_restriction    = var.enable_body_size_restriction != null ? var.enable_body_size_restriction : local.preset.enable_body_size_restriction
  effective_enable_sql_injection_protection = var.enable_sql_injection_protection != null ? var.enable_sql_injection_protection : local.preset.enable_sql_injection_protection
  effective_enable_known_bad_inputs         = var.enable_known_bad_inputs != null ? var.enable_known_bad_inputs : local.preset.enable_known_bad_inputs
  effective_enable_bot_control              = var.enable_bot_control != null ? var.enable_bot_control : local.preset.enable_bot_control

  # These two are always user-controlled (no preset logic needed)
  effective_enable_ip_allowlist = var.enable_ip_allowlist
  effective_enable_geo_block    = var.enable_geo_block
}
