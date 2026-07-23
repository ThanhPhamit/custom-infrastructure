# Validation: nlb_arn is required when load_balancer_type is "nlb"
locals {
  nlb_arn_validation = var.load_balancer_type == "nlb" && var.nlb_arn == null ? file("ERROR: nlb_arn is required when load_balancer_type is 'nlb'") : null

  # Secrets the task execution role may read: any externally-supplied ARNs plus
  # the optional managed app-secret container. The "-*" suffix matches the random
  # 6-char suffix Secrets Manager appends to the secret's ARN.
  managed_app_secret_arns = var.create_app_secret ? [
    "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.user.account_id}:secret:${var.app_name}-secrets-*"
  ] : []

  execution_secret_arns = concat(var.secret_arns, local.managed_app_secret_arns)
}
