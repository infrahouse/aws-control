module "tf_admins" {
  source = "./modules/tf_admin"
  for_each = toset(
    [
      "tf_github",
      "tf_aws",
      "tf_s3"
    ]
  )
  gh_secrets_namespace = aws_ssm_parameter.gh_secrets_namespace.insecure_value
  username             = each.key
  tags                 = merge(local.common_tags)
}
