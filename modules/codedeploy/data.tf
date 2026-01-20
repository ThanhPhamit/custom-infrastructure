data "aws_iam_policy" "codedeploy_role_policy" {
  arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}
