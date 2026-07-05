################################################################################
# Enhanced Monitoring IAM trust policy
################################################################################

# Trust policy allowing the RDS Enhanced Monitoring service to assume the role.
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    sid     = "RDSEnhancedMonitoringAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}
