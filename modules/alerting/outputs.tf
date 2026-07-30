output "sns_topic_arn" {
  description = "ARN of the incident alerts SNS topic. Consumed by the remediation module."
  value       = aws_sns_topic.incident_alerts.arn
}

output "slack_webhook_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Slack webhook URL. Populate its value out-of-band after apply."
  value       = var.enable_slack_alerts ? aws_secretsmanager_secret.slack_webhook[0].arn : null
}

output "slack_notifier_function_arn" {
  description = "ARN of the Slack notifier Lambda function."
  value       = var.enable_slack_alerts ? aws_lambda_function.slack_notifier[0].arn : null
}
