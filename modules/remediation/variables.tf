variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the CMK (from the kms module) used to encrypt Lambda environment variables and SQS DLQs."
  type        = string
}

variable "incident_table_name" {
  description = "Name of the DynamoDB incident table (from the logging module) that Lambdas write incident records to."
  type        = string
}

variable "incident_table_arn" {
  description = "ARN of the DynamoDB incident table (from the logging module)."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS alert topic (from the alerting module) that remediation Lambdas publish completion events to."
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime used by all remediation Lambda functions."
  type        = string
  default     = "python3.13"
}

variable "lambda_timeout_seconds" {
  description = "Timeout in seconds for remediation Lambda functions."
  type        = number
  default     = 60
}

variable "lambda_memory_mb" {
  description = "Memory allocation in MB for remediation Lambda functions."
  type        = number
  default     = 128
}

variable "enable_disable_iam_key_action" {
  description = "Whether to deploy the disable-compromised-IAM-key remediation function."
  type        = bool
  default     = true
}

variable "enable_quarantine_s3_action" {
  description = "Whether to deploy the quarantine-S3-bucket remediation function."
  type        = bool
  default     = true
}

variable "enable_revoke_session_action" {
  description = "Whether to deploy the revoke-active-session remediation function."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for Lambda function logs."
  type        = number
  default     = 90
}

variable "lambda_error_alarm_threshold" {
  description = "Number of errors within the evaluation period that triggers a CloudWatch alarm."
  type        = number
  default     = 1
}
