# Roles for CI/CD in the aws-control (aka main AWS) repo

module "ih-tf-aws-control-990466748045-admin" {
  source  = "infrahouse/gha-admin/aws"
  version = "~> 3.0"
  providers = {
    aws = aws.aws-990466748045-uw1
  }
  gh_identity_provider_arn = module.github-connector.gh_openid_connect_provider_arn
  repo_name                = "aws-control"
  state_bucket             = "infrahouse-aws-control-990466748045"
  gh_org_name              = "infrahouse"
  admin_allowed_arns = [
    local.me_arn
  ]
}
