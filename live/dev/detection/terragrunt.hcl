include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    logs_key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock-logs-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "logging" {
  config_path = "../logging"

  mock_outputs = {
    log_archive_bucket_name = "mock-log-bucket"
    log_archive_bucket_arn  = "arn:aws:s3:::mock-log-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "remediation" {
  config_path = "../remediation"

  mock_outputs = {
    playbook_arns = {
      disable_iam_key = "arn:aws:states:us-east-1:000000000000:stateMachine:mock-disable-iam-key"
      quarantine_s3    = "arn:aws:states:us-east-1:000000000000:stateMachine:mock-quarantine-s3"
      revoke_session   = "arn:aws:states:us-east-1:000000000000:stateMachine:mock-revoke-session"
    }
    eventbridge_invoke_role_arn = "arn:aws:iam::000000000000:role/mock-eventbridge-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

terraform {
  source = "${get_repo_root()}//modules/detection"
}

inputs = {
  kms_key_arn = dependency.kms.outputs.logs_key_arn

  log_archive_bucket_name     = dependency.logging.outputs.log_archive_bucket_name
  log_archive_bucket_arn      = dependency.logging.outputs.log_archive_bucket_arn
  eventbridge_target_arns     = dependency.remediation.outputs.playbook_arns
  eventbridge_target_role_arn = dependency.remediation.outputs.eventbridge_invoke_role_arn

  enable_cloudtrail    = true
  enable_guardduty     = true
  enable_aws_config    = true
  enable_vpc_flow_logs = true
  enable_security_hub  = true

  vpc_id                                 = include.root.locals.env_vars.locals.vpc_id
  flow_log_retention_days                = include.root.locals.env_vars.locals.flow_log_retention_days
  guardduty_finding_publishing_frequency = include.root.locals.env_vars.locals.guardduty_finding_frequency
}
