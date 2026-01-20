locals {
  tags = {
    "Project"     = "welfan-remark-ai-tool"
    "ManagedBy"   = "LionGarden.Inc"
    "Environment" = "${var.environment}"
  }

  app_name = "${var.environment}-${var.app_name}"
}

locals {
  account_id = data.aws_caller_identity.user.account_id
}
