output "logs_key_arn" {
  description = "ARN of the CMK used for CloudTrail, Config, and CloudWatch log encryption."
  value       = aws_kms_key.logs.arn
}

output "logs_key_id" {
  description = "Key ID of the logs CMK."
  value       = aws_kms_key.logs.key_id
}

output "dynamodb_key_arn" {
  description = "ARN of the CMK used for DynamoDB incident table encryption."
  value       = aws_kms_key.dynamodb.arn
}

output "sns_key_arn" {
  description = "ARN of the CMK used for SNS alert topic encryption."
  value       = aws_kms_key.sns.arn
}

output "secrets_key_arn" {
  description = "ARN of the CMK used for Secrets Manager encryption."
  value       = aws_kms_key.secrets.arn
}
