include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    sns_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock-sns-key"
    secrets_key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock-secrets-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

terraform {
  source = "${get_repo_root()}//modules/alerting"
}

inputs = {
  sns_kms_key_arn     = dependency.kms.outputs.sns_key_arn
  secrets_kms_key_arn = dependency.kms.outputs.secrets_key_arn

  alert_email_addresses = include.root.locals.env_vars.locals.alert_email_addresses
  alert_sms_numbers     = include.root.locals.env_vars.locals.alert_sms_numbers

  enable_slack_alerts = true
}
