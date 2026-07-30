include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    logs_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock-logs-key"
    dynamodb_key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock-dynamodb-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}//modules/logging"
}

inputs = {
  kms_key_arn          = dependency.kms.outputs.logs_key_arn
  dynamodb_kms_key_arn = dependency.kms.outputs.dynamodb_key_arn

  log_archive_bucket_name  = "irs-prod-log-archive-${include.root.locals.account_id}"
  log_archive_glacier_days = include.root.locals.env_vars.locals.log_archive_glacier_days
  cloudtrail_account_id    = include.root.locals.account_id

  incident_table_name         = "incidents"
  incident_table_billing_mode = include.root.locals.env_vars.locals.incident_table_billing_mode
}
