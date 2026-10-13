include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path  = "../kms"
  skip_outputs = tobool(get_env("TG_SKIP_DEPENDENCY_OUTPUTS", "false"))

  mock_outputs = {
    logs_key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock-logs-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "init-upgrade"]
}

dependency "logging" {
  config_path  = "../logging"
  skip_outputs = tobool(get_env("TG_SKIP_DEPENDENCY_OUTPUTS", "false"))

  mock_outputs = {
    incident_table_name = "mock-incidents"
    incident_table_arn  = "arn:aws:dynamodb:us-east-1:000000000000:table/mock-incidents"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "init-upgrade"]
}

dependency "alerting" {
  config_path  = "../alerting"
  skip_outputs = tobool(get_env("TG_SKIP_DEPENDENCY_OUTPUTS", "false"))

  mock_outputs = {
    sns_topic_arn = "arn:aws:sns:us-east-1:000000000000:mock-topic"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "init-upgrade"]
}

terraform {
  source = "${get_repo_root()}//modules/remediation"
}

inputs = {
  kms_key_arn         = dependency.kms.outputs.logs_key_arn
  incident_table_name = dependency.logging.outputs.incident_table_name
  incident_table_arn  = dependency.logging.outputs.incident_table_arn
  sns_topic_arn       = dependency.alerting.outputs.sns_topic_arn

  enable_disable_iam_key_action = true
  enable_quarantine_s3_action   = true
  enable_revoke_session_action  = true
}
