resource "aws_iam_group" "aws-admin" {
  name = "aws-admin"
}

resource "aws_iam_group_membership" "aws-admin" {
  name  = "tf-aws-admin-membership"
  group = aws_iam_group.aws-admin.name
  users = [
    aws_iam_user.aleks.name
  ]
}

resource "aws_iam_group_policy_attachment" "aws-admin" {
  group      = aws_iam_group.aws-admin.name
  policy_arn = aws_iam_policy.TFAWSAdmin.arn
}
