# State bucket for aws-control in the TF states account
module "state_bucket_990466748045" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-990466748045"
}

# CI/CD roles for aws-control (990466748045)
module "ih_tf_aws_control_990466748045" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws
    aws.cicd     = aws
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control"
  state_bucket              = module.state_bucket_990466748045.bucket_name
  terraform_locks_table_arn = module.state_bucket_990466748045.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
  allowed_arns = [
    "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
    "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
    "arn:aws:iam::303467602807:role/AWSControlTowerExecution",
  ]

  depends_on = [module.github_connector]
}

# SSM parameters in 990466748045 for backend discovery
module "ci_cd_params_990466748045" {
  source = "./modules/ci-cd-params"
  repo_name              = "aws-control"
  state_bucket           = module.state_bucket_990466748045.bucket_name
  lock_table             = module.state_bucket_990466748045.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_990466748045.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_990466748045.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_990466748045.admin_role_arn
}