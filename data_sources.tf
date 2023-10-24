data "aws_iam_policy" "administrator-access" {
  provider = aws.aws-990466748045-uw1
  name     = "AdministratorAccess"
}
data "aws_ssoadmin_instances" "sso" {
  provider = aws.aws-990466748045-uw1
}

