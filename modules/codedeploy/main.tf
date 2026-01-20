module "codedeploy_api_role" {
  source     = "../iam_role"
  name       = "${var.app_name}-codedeploy-role"
  identifier = "codedeploy.amazonaws.com"
  policy_arns_map = {
    "policy_1" = data.aws_iam_policy.codedeploy_role_policy.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-codedeploy-role"
    }
  )
}

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = var.app_name

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}"
    }
  )
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_config_name = var.deployment_config_name
  deployment_group_name  = "${var.app_name}-dg"
  service_role_arn       = module.codedeploy_api_role.iam_role_arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          var.lb_listener_prod_arn
        ]
      }

      test_traffic_route {
        listener_arns = [
          var.lb_listener_test_arn
        ]
      }

      target_group {
        name = var.lb_target_group_blue_name
      }

      target_group {
        name = var.lb_target_group_green_name
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-dg"
    }
  )
}

resource "random_uuid" "s3_bucket_postfix_uuid" {}

resource "aws_s3_bucket" "codedeploy_revisions" {
  bucket = "${var.app_name}-codedeploy-revisions-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-codedeploy-revisions-${substr(random_uuid.s3_bucket_postfix_uuid.result, 0, 3)}"
    }
  )
}

resource "aws_s3_bucket_versioning" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "codedeploy_revisions_policy" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.codedeploy_revisions.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "revision_appspec" {
  bucket = aws_s3_bucket.codedeploy_revisions.bucket
  key    = var.revision_appspec_key
  content = templatefile("${path.module}/appspec.yaml.tpl", {
    task_definition_arn = var.task_definition_arn
    container_name      = var.container_name
    container_port      = var.container_port
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-appspec"
    }
  )
}
