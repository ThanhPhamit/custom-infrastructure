################################################################################
# General
################################################################################

variable "app_name" {
  description = "Application/name prefix applied to every resource name and the Name tag (e.g. \"s2s-vpn-lab\")."
  type        = string

  validation {
    condition     = length(trimspace(var.app_name)) > 0
    error_message = "app_name must be a non-empty string."
  }
}

variable "tags" {
  description = "Additional tags merged onto every taggable resource created by this module."
  type        = map(string)
  default     = {}
}

################################################################################
# Identity naming
################################################################################

variable "bootstrap_user_name" {
  description = "Name of the bootstrap IAM user whose only permission is to assume the access role. Defaults to \"$${app_name}-bootstrap\" when null."
  type        = string
  default     = null
}

variable "access_role_name" {
  description = "Name of the access IAM role trusted by the bootstrap user. Defaults to \"$${app_name}-access-role\" when null."
  type        = string
  default     = null
}

variable "trust_source_vpce_ids" {
  description = "Optional VPC endpoint IDs (e.g. the STS interface endpoint). When non-empty, the access role can only be assumed through these endpoints (aws:SourceVpce condition), so a leaked bootstrap key cannot AssumeRole from outside the VPC/tunnel path."
  type        = list(string)
  default     = []
}

variable "trust_external_id" {
  description = "Optional sts:ExternalId required to assume the access role (a shared secret configured on the on-prem host's role profile). null disables the condition."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) for assumed sessions of the access role. AWS allows 3600 (1h) to 43200 (12h)."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 (1 hour) and 43200 (12 hours)."
  }
}

################################################################################
# Granted permissions (what the access role may do)
################################################################################

variable "db_secret_arn" {
  description = "ARN of the single Secrets Manager secret the access role is allowed to GetSecretValue (the DB credential secret)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:secretsmanager:", var.db_secret_arn))
    error_message = "db_secret_arn must be a valid Secrets Manager secret ARN (arn:aws:secretsmanager:...)."
  }
}

variable "enable_rds_iam_connect" {
  description = "When true, the access role is additionally granted rds-db:connect for one RDS IAM database user (RDS IAM auth token vending)."
  type        = bool
  default     = true
}

variable "rds_resource_id" {
  description = "Aurora cluster resource ID (cluster_resource_id, e.g. \"cluster-ABCDEF...\") used to build the rds-db:connect resource ARN. Required when enable_rds_iam_connect is true."
  type        = string
  default     = ""
}

variable "iam_db_username" {
  description = "RDS database user name embedded in the rds-db:connect resource ARN (the DB user that authenticates via IAM auth tokens)."
  type        = string
  default     = "app_iam"

  validation {
    condition     = length(trimspace(var.iam_db_username)) > 0
    error_message = "iam_db_username must be a non-empty string."
  }
}

################################################################################
# AWS account / region (used to construct the rds-db ARN; no hardcoding)
################################################################################

variable "aws_region" {
  description = "AWS region used to construct the rds-db:connect resource ARN (e.g. \"ap-southeast-1\")."
  type        = string

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region must be a non-empty string."
  }
}

variable "aws_account_id" {
  description = "AWS account ID (12 digits) used to construct the rds-db:connect resource ARN."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

################################################################################
# Lab convenience
################################################################################

variable "create_access_key" {
  description = "When true, create a programmatic access key for the bootstrap user. The secret lands in Terraform state; acceptable only for a throwaway lab (see README SECURITY NOTE)."
  type        = bool
  default     = true
}
