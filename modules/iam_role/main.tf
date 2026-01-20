resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}


# Attach multiple policies to the IAM role
resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.policy_arns_map

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
