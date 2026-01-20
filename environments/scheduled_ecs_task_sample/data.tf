data "aws_caller_identity" "user" {}

data "aws_iam_policy_document" "inserting_extracted_namecards_data_function_policy_1" {
  statement {
    actions   = ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface", "ec2:DescribeNetworkInterfaces"]
    resources = ["*"]
    effect    = "Allow"
  }
}
