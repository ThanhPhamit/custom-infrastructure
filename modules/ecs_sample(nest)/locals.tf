# Validation: nlb_arn is required when load_balancer_type is "nlb"
locals {
  nlb_arn_validation = var.load_balancer_type == "nlb" && var.nlb_arn == null ? file("ERROR: nlb_arn is required when load_balancer_type is 'nlb'") : null
}
