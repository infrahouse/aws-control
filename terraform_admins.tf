module "tf_admins" {
  source = "./modules/tf_admin"
  for_each = toset(
    [
      "tf_github",
      "tf_aws",
      "tf_s3"
    ]
  )
  username = each.key
  tags     = merge(local.common_tags)
}
