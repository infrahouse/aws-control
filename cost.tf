module "cost-alert" {
  providers = {
    aws = aws.aws-990466748045-ue1
  }
  source             = "registry.infrahouse.com/infrahouse/cost-alert/aws"
  version            = "1.0.0"
  alert_name         = "[infrahouse]: AWS daily cost"
  cost_threshold     = 18
  period_hours       = 24
  notification_email = "aleks@infrahouse.com"
}
