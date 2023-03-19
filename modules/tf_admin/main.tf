resource "aws_iam_user" "tf_admin" {
  name = var.username
  tags = var.tags
}

resource "aws_iam_access_key" "tf_admin" {
  user = aws_iam_user.tf_admin.name
}

resource "aws_secretsmanager_secret" "tf_admin" {
  name                    = "_github_control__tf_admin/${var.username}"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "version" {
  secret_id = aws_secretsmanager_secret.tf_admin.id
  secret_string = jsonencode(
    {
      "aws_access_key_id" : aws_iam_access_key.tf_admin.id
      "aws_secret_access_key" : aws_iam_access_key.tf_admin.secret
    }
  )
}
