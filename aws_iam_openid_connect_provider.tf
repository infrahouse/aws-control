module "github-connector" {
  source = "github.com/infrahouse/terraform-aws-gh-identity-provider"
  providers = {
    aws = aws.aws-990466748045-uw1
  }
}
