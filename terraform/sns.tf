resource "aws_sns_topic" "ip_change" {
  name = "ddns-ip-change"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ip_change.arn
  protocol  = "email"
  endpoint  = var.notify_email
}
