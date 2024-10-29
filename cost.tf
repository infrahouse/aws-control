module "cost-alert" {
  providers = {
    aws = aws.aws-990466748045-ue1
  }
  source             = "registry.infrahouse.com/infrahouse/cost-alert/aws"
  version            = "~> 0.1"
  cost_threshold     = 18
  notification_email = "aleks@infrahouse.com"
}
