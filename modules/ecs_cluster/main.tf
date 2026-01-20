locals {
  name = var.app_name
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(
    var.tags,
    {
      "Name" = local.name
    }
  )
}

