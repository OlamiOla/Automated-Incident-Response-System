output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector."
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "config_recorder_name" {
  description = "Name of the AWS Config configuration recorder."
  value       = var.enable_aws_config ? aws_config_configuration_recorder.main[0].name : null
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch Log Group receiving VPC Flow Logs."
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "security_hub_enabled" {
  description = "Whether Security Hub is enabled in this account/region."
  value       = var.enable_security_hub
}

output "eventbridge_rule_arns" {
  description = "Map of EventBridge rule name to ARN, for reference/debugging."
  value = {
    root_account_login = aws_cloudwatch_event_rule.root_account_login.arn
    guardduty_finding  = aws_cloudwatch_event_rule.guardduty_finding.arn
    s3_public_exposure = aws_cloudwatch_event_rule.s3_public_exposure.arn
  }
}
