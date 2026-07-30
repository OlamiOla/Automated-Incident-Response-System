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
  description = "ARN of the CMK (from the kms module) used to encrypt the log archive bucket."
  type        = string
}

variable "dynamodb_kms_key_arn" {
  description = "ARN of the CMK (from the kms module) used to encrypt the incident DynamoDB table."
  type        = string
}

variable "log_archive_bucket_name" {
  description = "Globally-unique name for the S3 log archive bucket."
  type        = string
}

variable "log_archive_glacier_days" {
  description = "Number of days before archived logs transition to S3 Glacier."
  type        = number
  default     = 90
}

variable "log_archive_expiration_days" {
  description = "Number of days before archived logs are permanently deleted. Set to 0 to retain indefinitely."
  type        = number
  default     = 0
}

variable "object_lock_retention_days" {
  description = "Number of days S3 Object Lock (compliance mode) prevents deletion/overwrite of log objects."
  type        = number
  default     = 365
}

variable "incident_table_name" {
  description = "Name of the DynamoDB table storing incident records."
  type        = string
  default     = "irs-incidents"
}

variable "incident_table_billing_mode" {
  description = "DynamoDB billing mode for the incident table (PAY_PER_REQUEST or PROVISIONED)."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "cloudtrail_account_id" {
  description = "AWS account ID that CloudTrail will write logs from (used in the bucket policy)."
  type        = string
}
