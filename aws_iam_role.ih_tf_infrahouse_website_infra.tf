# State bucket for infrahouse-website-infra in the TF states account
module "state_bucket_infrahouse_website_infra" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-website-infra"
}

# CI/CD roles for infrahouse-website-infra
module "ih_tf_infrahouse_website_infra" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-493370826424-uw1
    aws.cicd     = aws.aws-493370826424-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "infrahouse-website-infra"
  state_bucket              = module.state_bucket_infrahouse_website_infra.bucket_name
  terraform_locks_table_arn = module.state_bucket_infrahouse_website_infra.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
}

# SSM parameters in 493370826424 for backend discovery
module "ci_cd_params_infrahouse_website_infra" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-493370826424-uw1
  }
  repo_name              = "infrahouse-website-infra"
  state_bucket           = module.state_bucket_infrahouse_website_infra.bucket_name
  lock_table             = module.state_bucket_infrahouse_website_infra.lock_table_name
  state_manager_role_arn = module.ih_tf_infrahouse_website_infra.state_manager_role_arn
  github_role_arn        = module.ih_tf_infrahouse_website_infra.github_role_arn
  admin_role_arn         = module.ih_tf_infrahouse_website_infra.admin_role_arn
}