output "log_archive_bucket_name" {
  description = "Name of the S3 log archive bucket."
  value       = aws_s3_bucket.log_archive.id
}

output "log_archive_bucket_arn" {
  description = "ARN of the S3 log archive bucket."
  value       = aws_s3_bucket.log_archive.arn
}

output "incident_table_name" {
  description = "Name of the DynamoDB incident table."
  value       = aws_dynamodb_table.incidents.name
}

output "incident_table_arn" {
  description = "ARN of the DynamoDB incident table."
  value       = aws_dynamodb_table.incidents.arn
}

output "incident_table_stream_arn" {
  description = "ARN of the DynamoDB table's stream, if enabled (null unless stream is turned on)."
  value       = aws_dynamodb_table.incidents.stream_arn
}
