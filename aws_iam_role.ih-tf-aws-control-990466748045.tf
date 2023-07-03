# Roles for CI/CD in the aws-control (aka main AWS) repo

module "ih-tf-aws-control-990466748045-admin" {
  source = "github.com/infrahouse/terraform-aws-gha-admin"
  providers = {
    aws = aws.aws-990466748045-uw1
  }
  gh_identity_provider_arn = aws_iam_openid_connect_provider.github.arn
  repo_name                = "aws-control"
  state_bucket             = "infrahouse-aws-control-990466748045"
}