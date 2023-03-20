resource "aws_ssm_parameter" "gh_secrets_namespace" {
  name           = "gh_secrets_namespace"
  type           = "String"
  insecure_value = "_github_control__"
  tags           = merge(local.common_tags)
}
