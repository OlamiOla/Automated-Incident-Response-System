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

variable "log_archive_bucket_arn" {
  description = "ARN of the S3 bucket (from the logging module) that CloudTrail and Flow Logs write to."
  type        = string
}

variable "log_archive_bucket_name" {
  description = "Name of the S3 bucket (from the logging module) that CloudTrail writes to."
  type        = string
}

variable "enable_cloudtrail" {
  description = "Whether to create the account CloudTrail trail."
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty threat detection."
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "How often GuardDuty publishes findings."
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "enable_aws_config" {
  description = "Whether to enable AWS Config for configuration drift detection."
  type        = bool
  default     = true
}

variable "config_rules" {
  description = "List of AWS Config managed rule names to enable."
  type        = list(string)
  default = [
    "s3-bucket-public-read-prohibited",
    "s3-bucket-public-write-prohibited",
    "iam-user-unused-credentials-check",
    "root-account-mfa-enabled",
    "restricted-ssh"
  ]
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of the VPC to attach flow logs to. Required if enable_vpc_flow_logs is true."
  type        = string
  default     = null
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch Logs."
  type        = number
  default     = 90
}

variable "enable_security_hub" {
  description = "Whether to enable Security Hub."
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "List of Security Hub standards ARNs (suffixes) to subscribe to."
  type        = list(string)
  default = [
    "aws-foundational-security-best-practices/v/1.0.0",
    "cis-aws-foundations-benchmark/v/1.4.0"
  ]
}

variable "eventbridge_target_arns" {
  description = <<-EOT
    Map of remediation action name to the ARN it should be routed to
    (Step Functions state machine ARN, from the remediation module).
    Expected keys: disable_iam_key, quarantine_s3, revoke_session
  EOT
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the CMK (from the kms module) used to encrypt CloudTrail logs and CloudWatch/VPC Flow Logs."
  type        = string
}

variable "eventbridge_target_role_arn" {
  description = "IAM role ARN EventBridge assumes to invoke the Step Functions targets."
  type        = string
}
