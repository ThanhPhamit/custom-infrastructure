# =============================================================================
# Locals — centralised naming for resources to avoid string repetition in main.tf
# =============================================================================

locals {
  instance_name    = "${var.app_name}-server"
  static_ip_name   = "${var.app_name}-static-ip"
  iam_user_name    = "${var.app_name}-lightsail-app"
  credentials_name = "${var.app_name}-lightsail-app-credentials"

  # Common tag merge — always includes ManagedBy
  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
  })
}
