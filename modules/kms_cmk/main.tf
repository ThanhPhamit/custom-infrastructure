data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  description = var.description != "" ? var.description : "Customer-managed CMK for ${var.app_name} (EBS, RDS at-rest, SSM SecureString)."
}

# Key policy. Statement 1 is the AWS-recommended anti-lockout baseline: the account root retains
# full control and IAM policies govern actual usage (so a consumer role granted kms:Decrypt in ITS
# OWN policy can use the key without being named here — this is what avoids a circular dependency
# between this key policy and the EC2 instance role that decrypts with it).
data "aws_iam_policy_document" "key" {
  statement {
    sid       = "EnableRootAndIamDelegation"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.key_administrator_arns) > 0 ? [1] : []
    content {
      sid    = "KeyAdministrators"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
        "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
        "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.key_administrator_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_user_arns) > 0 ? [1] : []
    content {
      sid    = "KeyUsers"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.key_user_arns
      }
    }
  }

  # Lets AWS services (RDS, EBS) create grants on behalf of the account when they use the key.
  dynamic "statement" {
    for_each = length(var.key_user_arns) > 0 ? [1] : []
    content {
      sid       = "KeyUsersCreateGrantForAwsResources"
      effect    = "Allow"
      actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.key_user_arns
      }
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = local.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = var.multi_region
  policy                  = data.aws_iam_policy_document.key.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-cmk"
    ManagedBy = "Terraform"
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.app_name}"
  target_key_id = aws_kms_key.this.key_id
}
