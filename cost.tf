resource "aws_cloudwatch_metric_alarm" "daily0spend" {
  alarm_name          = "daily_cost"
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  period              = 6 * 3600
  evaluation_periods  = 1
  statistic           = "Maximum"
  datapoints_to_alarm = 1
  alarm_actions = [
    aws_sns_topic.cost_notifications.arn
  ]
}

resource "aws_sns_topic" "cost_notifications" {
  name_prefix = "cost-daily-"
}

resource "aws_sns_topic_subscription" "cost_emails" {
  endpoint  = "aleks@infrahouse.com"
  protocol  = "email"
  topic_arn = aws_sns_topic.cost_notifications.arn
}
