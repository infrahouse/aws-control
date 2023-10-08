data "aws_iam_policy_document" "aws-admin" {
  provider = aws.aws-990466748045-uw1
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_user.aleks.arn,
        aws_iam_user.tmp.arn
      ]
    }
  }
}
resource "aws_iam_role" "aws-admin" {
  provider           = aws.aws-990466748045-uw1
  name               = "aws-admin"
  assume_role_policy = data.aws_iam_policy_document.aws-admin.json
}

resource "aws_iam_role_policy_attachment" "aws-admin" {
  provider   = aws.aws-990466748045-uw1
  policy_arn = data.aws_iam_policy.administrator-access.arn
  role       = aws_iam_role.aws-admin.name
}
