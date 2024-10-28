resource "aws_cloudwatch_metric_alarm" "daily0spend" {
  provider            = aws.aws-990466748045-ue1
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
<<<<<<< HEAD
  depends_on = [
    aws_sns_topic.cost_notifications
  ]
=======
>>>>>>> d8e7d9f (move cost alert to us-east-1)
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
