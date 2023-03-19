resource "aws_iam_user" "aleks" {
  name = "aleks"
  tags = merge(local.common_tags)
}

resource "aws_iam_access_key" "aleks" {
  user = aws_iam_user.aleks.name
}

resource "aws_iam_user" "twindb_test_runner" {
  name = "twindb_test_runner"
  tags = merge(local.common_tags)
}

resource "aws_iam_access_key" "twindb_test_runner" {
  user = aws_iam_user.twindb_test_runner.name
}

resource "aws_iam_user_policy_attachment" "twindb_test_runner" {
  policy_arn = aws_iam_policy.TwinDBTestRunner.arn
  user       = aws_iam_user.twindb_test_runner.name
}
