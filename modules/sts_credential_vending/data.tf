################################################################################
# Trust policy: who may assume the access role
# (only the bootstrap IAM user created by this module)
################################################################################

data "aws_iam_policy_document" "access_trust" {
  statement {
    sid     = "BootstrapUserAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.bootstrap.arn]
    }

    # Optional: restrict assumption to requests arriving through specific VPC
    # endpoint(s) (the STS interface endpoint), so a leaked bootstrap key cannot
    # AssumeRole from outside the VPC/tunnel path.
    dynamic "condition" {
      for_each = length(var.trust_source_vpce_ids) > 0 ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:SourceVpce"
        values   = var.trust_source_vpce_ids
      }
    }

    # Optional: require a shared sts:ExternalId.
    dynamic "condition" {
      for_each = var.trust_external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.trust_external_id]
      }
    }
  }
}

################################################################################
# Access role permissions: read ONE secret, optionally mint RDS IAM tokens
################################################################################

data "aws_iam_policy_document" "access_permissions" {
  statement {
    sid       = "ReadDbSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }

  dynamic "statement" {
    for_each = var.enable_rds_iam_connect ? [1] : []

    content {
      sid       = "RdsIamConnect"
      effect    = "Allow"
      actions   = ["rds-db:connect"]
      resources = [local.rds_db_arn]
    }
  }
}

################################################################################
# Bootstrap user permissions: assume the access role and nothing else
################################################################################

data "aws_iam_policy_document" "bootstrap_assume_only" {
  statement {
    sid       = "AssumeAccessRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.access.arn]
  }
}
