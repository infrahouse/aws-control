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
resource "aws_ssm_parameter" "tf_state_bucket_338531211565" {
  provider = aws.aws-338531211565-uw1
  name     = "/terraform/backend/state_bucket"
  type     = "String"
  value    = module.state_bucket_338531211565.bucket_name
}

resource "aws_ssm_parameter" "tf_lock_table_338531211565" {
  provider = aws.aws-338531211565-uw1
  name     = "/terraform/backend/lock_table"
  type     = "String"
  value    = module.state_bucket_338531211565.lock_table_name
}

resource "aws_ssm_parameter" "tf_state_manager_role_arn_338531211565" {
  provider = aws.aws-338531211565-uw1
  name     = "/terraform/backend/state_manager_role_arn"
  type     = "String"
  value    = module.ih_tf_aws_control_338531211565.state_manager_role_arn
}

resource "aws_ssm_parameter" "tf_github_role_arn_338531211565" {
  provider = aws.aws-338531211565-uw1
  name     = "/terraform/ci-cd/github_role_arn"
  type     = "String"
  value    = module.ih_tf_aws_control_338531211565.github_role_arn
}

resource "aws_ssm_parameter" "tf_admin_role_arn_338531211565" {
  provider = aws.aws-338531211565-uw1
  name     = "/terraform/ci-cd/admin_role_arn"
  type     = "String"
  value    = module.ih_tf_aws_control_338531211565.admin_role_arn
}
