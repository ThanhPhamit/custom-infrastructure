# =============================================================================
# Lightsail Instance — generic reusable module
# Provides: Instance + Static IP + (optional) Key Pair + Firewall + IAM user
# IAM policies are supplied by the caller (no app-specific policies here).
#
# NOTE: Lightsail instances run in an AWS-managed account (not the caller's).
# IMDS credentials on the instance belong to that managed account and cannot
# be controlled by the caller. Use create_iam_user = true to provision an IAM
# user with explicit access keys — the only supported way to give a Lightsail
# instance access to the caller's AWS services (S3, SES, SNS, ECR, etc.).
# =============================================================================

# ===== Lightsail Instance =====
resource "aws_lightsail_instance" "this" {
  name              = local.instance_name
  availability_zone = "${var.region}${var.availability_zone_suffix}"
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  key_pair_name     = var.key_pair_name != null ? aws_lightsail_key_pair.this[0].name : null

  user_data = var.user_data

  tags = merge(local.common_tags, {
    Name = local.instance_name
  })
}

# ===== SSH Key Pair (optional — created from public key) =====
resource "aws_lightsail_key_pair" "this" {
  count = var.key_pair_name != null ? 1 : 0

  name       = "${var.app_name}-${var.key_pair_name}"
  public_key = var.public_key
}

# ===== Static IP =====
resource "aws_lightsail_static_ip" "this" {
  name = local.static_ip_name
}

resource "aws_lightsail_static_ip_attachment" "this" {
  static_ip_name = aws_lightsail_static_ip.this.name
  instance_name  = aws_lightsail_instance.this.name
}

# ===== Firewall Rules =====
resource "aws_lightsail_instance_public_ports" "this" {
  count = length(var.port_rules) > 0 ? 1 : 0

  instance_name = aws_lightsail_instance.this.name

  dynamic "port_info" {
    for_each = var.port_rules
    content {
      protocol  = port_info.value.protocol
      from_port = port_info.value.from_port
      to_port   = port_info.value.to_port
      cidrs     = port_info.value.cidrs
    }
  }
}

# =============================================================================
# IAM User (optional) — Lightsail has no user-controlled instance role.
# Use explicit IAM user + access keys for app access to AWS services.
# Policies are provided by the caller via var.iam_policies.
# Credentials are stored in Secrets Manager (not in tfstate outputs).
# =============================================================================
resource "aws_iam_user" "app" {
  count = var.create_iam_user ? 1 : 0

  name = local.iam_user_name
  tags = merge(local.common_tags, {
    Name = local.iam_user_name
  })
}

resource "aws_iam_access_key" "app" {
  count = var.create_iam_user ? 1 : 0

  user = aws_iam_user.app[0].name
}

resource "aws_iam_policy" "custom" {
  for_each = var.create_iam_user ? var.iam_policies : {}

  name_prefix = "${var.app_name}-${each.key}-"
  policy      = each.value

  tags = merge(local.common_tags, {
    Name = "${var.app_name}-${each.key}"
  })
}

resource "aws_iam_user_policy_attachment" "custom" {
  for_each = var.create_iam_user ? var.iam_policies : {}

  user       = aws_iam_user.app[0].name
  policy_arn = aws_iam_policy.custom[each.key].arn
}

resource "aws_secretsmanager_secret" "app_credentials" {
  count = var.create_iam_user ? 1 : 0

  name_prefix = "${local.credentials_name}-"
  description = "IAM credentials for Lightsail app (${var.app_name})"
  tags = merge(local.common_tags, {
    Name = local.credentials_name
  })
}

resource "aws_secretsmanager_secret_version" "app_credentials" {
  count = var.create_iam_user ? 1 : 0

  secret_id = aws_secretsmanager_secret.app_credentials[0].id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.app[0].id
    secret_access_key = aws_iam_access_key.app[0].secret
  })
}
