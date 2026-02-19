data "aws_iam_policy" "administrator-access" {
  name = "AdministratorAccess"
}
data "aws_ssoadmin_instances" "sso" {}
data "aws_iam_roles" "sso_admin" {
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
}
