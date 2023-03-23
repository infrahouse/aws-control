resource "aws_iam_user" "aleks" {
  name = "aleks"
  tags = merge(local.common_tags)
}

resource "aws_iam_access_key" "aleks" {
  user = aws_iam_user.aleks.name
}
