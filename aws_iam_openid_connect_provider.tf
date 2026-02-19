moved {
  from = module.github-connector
  to   = module.github_connector
}

module "github_connector" {
  source  = "infrahouse/gh-identity-provider/aws"
  version = "1.1.1"
}
