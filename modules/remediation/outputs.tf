output "playbook_arns" {
  description = "Map of remediation action name to its Step Functions state machine ARN. Consumed by the detection module's EventBridge targets."
  value       = { for k, v in aws_sfn_state_machine.playbook : k => v.arn }
}

output "eventbridge_invoke_role_arn" {
  description = "IAM role ARN EventBridge assumes to start Step Functions executions. Consumed by the detection module."
  value       = aws_iam_role.eventbridge_invoke.arn
}

output "lambda_function_arns" {
  description = "Map of remediation action name to its Lambda function ARN."
  value       = { for k, v in aws_lambda_function.function : k => v.arn }
}

output "dlq_arns" {
  description = "Map of remediation action name to its dead-letter queue ARN."
  value       = { for k, v in aws_sqs_queue.dlq : k => v.arn }
}
