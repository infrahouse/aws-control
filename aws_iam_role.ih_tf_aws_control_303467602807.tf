# State bucket for aws-control-303467602807 in the TF states account
module "state_bucket_303467602807" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-303467602807"
}

# CI/CD roles for aws-control-303467602807
module "ih_tf_aws_control_303467602807" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-303467602807-uw1
    aws.cicd     = aws.aws-303467602807-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-303467602807"
  state_bucket              = module.state_bucket_303467602807.bucket_name
  terraform_locks_table_arn = module.state_bucket_303467602807.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
}

# Read-only state access for 493370826424 to read 303467602807 state
module "ih_tf_aws_control_303467602807_state_manager_read_only" {
  source  = "infrahouse/state-manager/aws"
  version = "1.4.2"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  name = "ih-tf-aws-control-303467602807-state-manager-read-only"
  assuming_role_arns = [
    "arn:aws:iam::493370826424:role/ih-tf-aws-control-493370826424-github",
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
  state_bucket              = module.state_bucket_303467602807.bucket_name
  terraform_locks_table_arn = module.state_bucket_303467602807.lock_table_arn
  read_only_permissions     = true
}

# SSM parameters in 303467602807 for backend discovery
module "ci_cd_params_303467602807" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-303467602807-uw1
  }
  repo_name              = "aws-control-303467602807"
  state_bucket           = module.state_bucket_303467602807.bucket_name
  lock_table             = module.state_bucket_303467602807.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_303467602807.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_303467602807.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_303467602807.admin_role_arn
}