resource "aws_iam_user" "tf_admin" {
  name = var.username
  tags = var.tags
}

resource "aws_iam_access_key" "tf_admin" {
  user = aws_iam_user.tf_admin.name
}
