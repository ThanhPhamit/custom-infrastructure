# Get VPC information including CIDR block
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_cidrs = [for assoc in data.aws_vpc.selected.cidr_block_associations : assoc.cidr_block]
}


# Data source to get the actual IP addresses from network interfaces
# Only fetch ENIs when we need to get dynamic IPs (not using fixed IPs)
data "aws_network_interfaces" "nlb_enis" {
  count = var.use_fixed_ips ? 0 : 1

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.nlb.arn_suffix}"]
  }

  depends_on = [aws_lb.nlb]
}
