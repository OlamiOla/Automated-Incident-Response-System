locals {
  vpc_id                         = "vpc-REPLACE_WITH_DEV_VPC_ID"
  alert_email_addresses          = ["REPLACE_WITH_DEV_ALERT_EMAIL@yourcompany.com"]
  alert_sms_numbers               = []
  flow_log_retention_days        = 30
  cloudtrail_log_retention_days  = 90
  log_archive_glacier_days       = 30
  guardduty_finding_frequency    = "SIX_HOURS"
  key_deletion_window_days       = 7
  incident_table_billing_mode    = "PAY_PER_REQUEST"
}
