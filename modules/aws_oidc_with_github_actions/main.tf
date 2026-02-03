resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = var.oidc_url
  client_id_list  = var.client_id_list
  thumbprint_list = var.thumbprint_list
  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-github-oidc-provider"
    }
  )
}

resource "aws_iam_role" "github" {
  name                 = "${var.app_name}-${var.iam_role_name}"
  description          = var.iam_role_description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration
  path                 = var.iam_role_path

  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-${var.iam_role_name}"
    }
  )
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTagsForResource",
      "ecs:TagResource",
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:UpdateService",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetApplicationRevision",
      "ecs:DescribeTaskDefinition",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:DeleteObject",
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:UpdateService",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation"
    ]

    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = var.passrole_target_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "${var.app_name}-github-actions-policy"
  description = "Policy for GitHub Actions"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = merge(
    var.tags,
    {
      "Name" = "${var.app_name}-github-actions-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "policy" {
  role       = aws_iam_role.github.id
  policy_arn = aws_iam_policy.github_actions_policy.arn
}
