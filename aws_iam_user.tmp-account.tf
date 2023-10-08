resource "aws_iam_user" "tmp" {
  provider = aws.aws-990466748045-uw1
  name     = "tmp"
}

resource "aws_iam_access_key" "aleks" {
  provider = aws.aws-990466748045-uw1
  user     = aws_iam_user.tmp.name
}

resource "aws_iam_user_policy_attachment" "tmp" {
  provider   = aws.aws-990466748045-uw1
  policy_arn = data.aws_iam_policy.administrator-access.arn
  user       = aws_iam_user.tmp.name
}
