locals {
  bootstrap_user_name = coalesce(var.bootstrap_user_name, "${var.app_name}-bootstrap")
  access_role_name    = coalesce(var.access_role_name, "${var.app_name}-access-role")

  # IAM DB-auth ARN separator after "dbuser" MUST be a colon, not a slash:
  # arn:aws:rds-db:<region>:<acct>:dbuser:<DbClusterResourceId>/<db-user>.
  # RDS authorizes rds-db:connect against the COLON form; a slash-form grant
  # (dbuser/<id>/<user>) is a literally different ARN string and never matches
  # → implicit deny → "PAM authentication failed". Proven via authoritative AWS
  # doc (UsingWithRDS.IAMDBAuth.IAMPolicy) + simulate-principal-policy (colon
  # form = implicitDeny under the old slash grant). 2026-07-03.
  rds_db_arn = "arn:aws:rds-db:${var.aws_region}:${var.aws_account_id}:dbuser:${var.rds_resource_id}/${var.iam_db_username}"
}

################################################################################
# Bootstrap IAM user (the on-prem host's only long-lived identity)
################################################################################

resource "aws_iam_user" "bootstrap" {
  name = local.bootstrap_user_name

  tags = merge(var.tags, {
    Name      = local.bootstrap_user_name
    ManagedBy = "Terraform"
  })
}

resource "aws_iam_access_key" "bootstrap" {
  count = var.create_access_key ? 1 : 0

  user = aws_iam_user.bootstrap.name
}

# The bootstrap user may ONLY assume the access role.
resource "aws_iam_user_policy" "bootstrap" {
  name   = "${var.app_name}-bootstrap-assume-only"
  user   = aws_iam_user.bootstrap.name
  policy = data.aws_iam_policy_document.bootstrap_assume_only.json
}

################################################################################
# Access IAM role (assumed via STS; holds the actual data-plane grants)
################################################################################

resource "aws_iam_role" "access" {
  name                 = local.access_role_name
  assume_role_policy   = data.aws_iam_policy_document.access_trust.json
  max_session_duration = var.max_session_duration

  tags = merge(var.tags, {
    Name      = local.access_role_name
    ManagedBy = "Terraform"
  })
}

resource "aws_iam_role_policy" "access" {
  name   = "${var.app_name}-access-policy"
  role   = aws_iam_role.access.id
  policy = data.aws_iam_policy_document.access_permissions.json

  lifecycle {
    precondition {
      condition     = !var.enable_rds_iam_connect || length(trimspace(var.rds_resource_id)) > 0
      error_message = "rds_resource_id must be a non-empty Aurora cluster resource ID when enable_rds_iam_connect is true."
    }
  }
}
