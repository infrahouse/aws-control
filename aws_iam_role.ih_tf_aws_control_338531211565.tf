# State bucket for aws-control-338531211565 in the TF states account
module "state_bucket_338531211565" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-338531211565"
}

# OIDC provider for GitHub Actions in 338531211565
module "github_connector_338531211565" {
  source  = "infrahouse/gh-identity-provider/aws"
  version = "1.1.1"
  providers = {
    aws = aws.aws-338531211565-uw1
  }
}

# CI/CD roles for aws-control-338531211565
module "ih_tf_aws_control_338531211565" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-338531211565-uw1
    aws.cicd     = aws.aws-338531211565-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-338531211565"
  state_bucket              = module.state_bucket_338531211565.bucket_name
  terraform_locks_table_arn = module.state_bucket_338531211565.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]

  depends_on = [module.github_connector_338531211565]
}

# SSM parameters in 338531211565 for backend discovery
module "ci_cd_params_338531211565" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-338531211565-uw1
  }
  repo_name              = "aws-control-338531211565"
  state_bucket           = module.state_bucket_338531211565.bucket_name
  lock_table             = module.state_bucket_338531211565.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_338531211565.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_338531211565.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_338531211565.admin_role_arn
}
