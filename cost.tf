resource "aws_cloudwatch_metric_alarm" "daily-spend" {
  provider            = aws.aws-990466748045-ue1
  alarm_name          = "daily_cost"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  metric_query {
    id = "m1"
    metric {
      metric_name = "EstimatedCharges"
      namespace   = "AWS/Billing"
      period      = 24 * 3600
      stat        = "Maximum"
      dimensions = {
        "Currency" = "USD"
      }
    }
  }

  metric_query {
    id          = "e1"
    expression  = "RATE(m1) * 24 * 3600"
    label       = "Daily cost"
    return_data = true
  }

  alarm_actions = [
    aws_sns_topic.cost_notifications.arn
  ]
}

resource "aws_sns_topic" "cost_notifications" {
  provider    = aws.aws-990466748045-ue1
  name_prefix = "cost-daily-"
}

resource "aws_sns_topic_subscription" "cost_emails" {
  provider  = aws.aws-990466748045-ue1
  endpoint  = "aleks@infrahouse.com"
  protocol  = "email"
  topic_arn = aws_sns_topic.cost_notifications.arn
}
