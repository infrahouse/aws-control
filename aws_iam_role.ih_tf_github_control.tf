# State bucket for github-control in the TF states account
module "state_bucket_github_control" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-github-control-state"
}

# CI/CD roles for github-control
module "ih_tf_github_control" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-303467602807-uw1
    aws.cicd     = aws.aws-303467602807-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse8"
  repo_name                 = "github-control"
  state_bucket              = module.state_bucket_github_control.bucket_name
  terraform_locks_table_arn = module.state_bucket_github_control.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
  allowed_arns = [
    "arn:aws:iam::289256138624:role/ih-tf-aws-control-289256138624-admin",
    "arn:aws:iam::493370826424:role/ih-tf-aws-control-493370826424-admin",
  ]
}

# SSM parameters in 303467602807 for backend discovery
module "ci_cd_params_github_control" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-303467602807-uw1
  }
  repo_name              = "github-control"
  state_bucket           = module.state_bucket_github_control.bucket_name
  lock_table             = module.state_bucket_github_control.lock_table_name
  state_manager_role_arn = module.ih_tf_github_control.state_manager_role_arn
  github_role_arn        = module.ih_tf_github_control.github_role_arn
  admin_role_arn         = module.ih_tf_github_control.admin_role_arn
}