module "github-connector" {
  source  = "infrahouse/gh-identity-provider/aws"
  version = "1.1.1"
  providers = {
    aws = aws.aws-990466748045-uw1
  }
}
