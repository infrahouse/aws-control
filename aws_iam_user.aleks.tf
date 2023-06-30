resource "aws_iam_user" "aleks" {
  provider = aws.aws-990466748045-uw1
  name     = "aleks"
}

resource "aws_iam_access_key" "aleks" {
  provider = aws.aws-990466748045-uw1
  user     = aws_iam_user.aleks.name
}

resource "aws_iam_user_policy_attachment" "aleks" {
  provider   = aws.aws-990466748045-uw1
  policy_arn = aws_iam_policy.allow-assume.arn
  user       = aws_iam_user.aleks.name
}
