# State bucket for aws-control-493370826424 in the TF states account
module "state_bucket_493370826424" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-493370826424"
}

# CI/CD roles for aws-control-493370826424
module "ih_tf_aws_control_493370826424" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-493370826424-uw1
    aws.cicd     = aws.aws-493370826424-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-493370826424"
  state_bucket              = module.state_bucket_493370826424.bucket_name
  terraform_locks_table_arn = module.state_bucket_493370826424.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
    "arn:aws:iam::303467602807:role/ih-tf-github-control-github",
  ]
  allowed_arns = [
    "arn:aws:iam::289256138624:role/ih-tf-aws-control-303467602807-state-manager-read-only",
  ]
}

# SSM parameters in 493370826424 for backend discovery
module "ci_cd_params_493370826424" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-493370826424-uw1
  }
  repo_name              = "aws-control-493370826424"
  state_bucket           = module.state_bucket_493370826424.bucket_name
  lock_table             = module.state_bucket_493370826424.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_493370826424.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_493370826424.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_493370826424.admin_role_arn
}