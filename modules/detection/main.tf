# =====================================================
# DATA SOURCES
# =====================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =====================================================
# CLOUDTRAIL
# =====================================================

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = var.log_archive_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags
}

# =====================================================
# GUARDDUTY
# =====================================================

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  tags = var.tags
}

# =====================================================
# AWS CONFIG
# =====================================================

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.project_name}-${var.environment}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_aws_config ? 1 : 0
  name           = "${var.project_name}-${var.environment}-delivery-channel"
  s3_bucket_name = var.log_archive_bucket_name

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_config_rule" "managed" {
  for_each = var.enable_aws_config ? toset(var.config_rules) : []

  name = "${var.project_name}-${var.environment}-${each.value}"

  source {
    owner             = "AWS"
    source_identifier = upper(replace(each.value, "-", "_"))
  }

  depends_on = [aws_config_configuration_recorder.main]
  tags       = var.tags
}

# =====================================================
# VPC FLOW LOGS
# =====================================================

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-flow-logs-policy"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count           = var.enable_vpc_flow_logs ? 1 : 0
  vpc_id          = var.vpc_id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn    = aws_iam_role.flow_logs[0].arn

  tags = var.tags
}

# =====================================================
# SECURITY HUB
# =====================================================

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each = var.enable_security_hub ? toset(var.security_hub_standards) : []

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/${each.value}"

  depends_on = [aws_securityhub_account.main]
}

# =====================================================
# EVENTBRIDGE — routes findings to remediation playbooks
# =====================================================

resource "aws_cloudwatch_event_rule" "root_account_login" {
  name        = "${var.project_name}-${var.environment}-root-login"
  description = "Matches CloudTrail root account login events"

  event_pattern = jsonencode({
    source      = ["aws.signin"]
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = { type = ["Root"] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "root_account_login" {
  count    = contains(keys(var.eventbridge_target_arns), "revoke_session") ? 1 : 0
  rule     = aws_cloudwatch_event_rule.root_account_login.name
  arn      = var.eventbridge_target_arns["revoke_session"]
  role_arn = var.eventbridge_target_role_arn
}

resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name        = "${var.project_name}-${var.environment}-guardduty-finding"
  description = "Matches GuardDuty findings for compromised credentials"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [{ prefix = "UnauthorizedAccess:IAMUser" }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_finding" {
  count    = contains(keys(var.eventbridge_target_arns), "disable_iam_key") ? 1 : 0
  rule     = aws_cloudwatch_event_rule.guardduty_finding.name
  arn      = var.eventbridge_target_arns["disable_iam_key"]
  role_arn = var.eventbridge_target_role_arn
}

resource "aws_cloudwatch_event_rule" "s3_public_exposure" {
  name        = "${var.project_name}-${var.environment}-s3-public-exposure"
  description = "Matches Config findings for publicly exposed S3 buckets"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName      = [{ prefix = "${var.project_name}-${var.environment}-s3-bucket-public" }]
      newEvaluationResult = { complianceType = ["NON_COMPLIANT"] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "s3_public_exposure" {
  count    = contains(keys(var.eventbridge_target_arns), "quarantine_s3") ? 1 : 0
  rule     = aws_cloudwatch_event_rule.s3_public_exposure.name
  arn      = var.eventbridge_target_arns["quarantine_s3"]
  role_arn = var.eventbridge_target_role_arn
}
