locals {
  vpc_id                         = "vpc-REPLACE_WITH_PROD_VPC_ID"
  alert_email_addresses          = ["REPLACE_WITH_PROD_ALERT_EMAIL@yourcompany.com"]
  alert_sms_numbers               = ["+1REPLACE_WITH_PROD_PHONE"]
  flow_log_retention_days        = 365
  cloudtrail_log_retention_days  = 365
  log_archive_glacier_days       = 90
  guardduty_finding_frequency    = "FIFTEEN_MINUTES"
  key_deletion_window_days       = 30
  incident_table_billing_mode    = "PAY_PER_REQUEST"
}
