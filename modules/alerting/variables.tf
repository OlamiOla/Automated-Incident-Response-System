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

variable "sns_kms_key_arn" {
  description = "ARN of the CMK (from the kms module) used to encrypt the SNS alert topic."
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "ARN of the CMK (from the kms module) used to encrypt Secrets Manager secrets."
  type        = string
}

variable "alert_email_addresses" {
  description = "List of email addresses subscribed to incident alerts via SNS."
  type        = list(string)
  default     = []
}

variable "alert_sms_numbers" {
  description = "List of phone numbers (E.164 format) subscribed to incident alerts via SNS."
  type        = list(string)
  default     = []
}

variable "enable_slack_alerts" {
  description = "Whether to deploy the Slack notification Lambda and its SNS subscription."
  type        = bool
  default     = false
}

variable "lambda_runtime" {
  description = "Runtime used by the Slack notifier Lambda."
  type        = string
  default     = "python3.13"
}

variable "lambda_timeout_seconds" {
  description = "Timeout in seconds for the Slack notifier Lambda."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for the Slack notifier Lambda."
  type        = number
  default     = 90
}
