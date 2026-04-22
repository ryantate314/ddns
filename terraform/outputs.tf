output "api_invoke_url" {
  description = "Base URL for the API Gateway stage. POST to <url>/update."
  value       = "${aws_api_gateway_stage.prod.invoke_url}/update"
}

output "api_key_value" {
  description = "API key to send in the x-api-key header. Sensitive."
  value       = aws_api_gateway_api_key.client.value
  sensitive   = true
}

output "sns_topic_arn" {
  description = "SNS topic ARN for IP-change notifications."
  value       = aws_sns_topic.ip_change.arn
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID the Lambda updates."
  value       = data.aws_route53_zone.zone.zone_id
}

output "record_name" {
  description = "DNS record name managed by this stack."
  value       = local.record_fqdn
}
