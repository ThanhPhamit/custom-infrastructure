data "aws_partition" "current" {}

# DLM service role — assumed by dlm.amazonaws.com, with the AWS-managed policy that lets DLM
# create/delete/tag EBS snapshots on the account's behalf.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name_prefix        = "${var.app_name}-dlm-"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, {
    Name      = "${var.app_name}-dlm-role"
    ManagedBy = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "this" {
  # DLM description allows only [0-9A-Za-z _-] — no parentheses/commas.
  description        = "${var.app_name} EBS snapshots every ${var.schedule_interval_hours}h retain ${var.retain_count}"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    policy_type    = "EBS_SNAPSHOT_MANAGEMENT"
    resource_types = [var.resource_type]
    target_tags    = var.target_tags

    # exclude_boot_volume is only valid for INSTANCE policies.
    dynamic "parameters" {
      for_each = var.resource_type == "INSTANCE" ? [1] : []
      content {
        exclude_boot_volume = var.exclude_boot_volume
      }
    }

    schedule {
      name = "snapshots"

      create_rule {
        interval      = var.schedule_interval_hours
        interval_unit = "HOURS"
        times         = var.schedule_times
      }

      retain_rule {
        count = var.retain_count
      }

      copy_tags = var.copy_tags
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.app_name}-dlm"
    ManagedBy = "Terraform"
  })
}
