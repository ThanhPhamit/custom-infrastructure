data "aws_iam_openid_connect_provider" "existing_github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = var.oidc_url
}

locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing_github[0].arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = "1"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Explicit subject_claims (exact, no wildcard) when provided — else the permissive
    # repo:<org>/<repo>:* default (any branch/PR/tag). Prefer explicit in production.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = length(var.subject_claims) > 0 ? var.subject_claims : [
        for repo in var.github_repositories : "repo:${var.github_org}/${repo}:*"
      ]
    }
  }
}
