data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# =====================================================
# SNS — INCIDENT ALERT TOPIC
# =====================================================

resource "aws_sns_topic" "incident_alerts" {
  name              = "${var.project_name}-${var.environment}-incident-alerts"
  kms_master_key_id = var.sns_kms_key_arn

  tags = var.tags
}

resource "aws_sns_topic_policy" "incident_alerts" {
  arn = aws_sns_topic.incident_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountPublish"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.incident_alerts.arn
      },
      {
        Sid       = "AllowCloudWatchAlarmPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.incident_alerts.arn
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.incident_alerts.arn
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_email_addresses)

  topic_arn = aws_sns_topic.incident_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "sms" {
  for_each = toset(var.alert_sms_numbers)

  topic_arn = aws_sns_topic.incident_alerts.arn
  protocol  = "sms"
  endpoint  = each.value
}

# =====================================================
# SECRETS MANAGER — SLACK WEBHOOK
# =====================================================

resource "aws_secretsmanager_secret" "slack_webhook" {
  count = var.enable_slack_alerts ? 1 : 0

  name       = "${var.project_name}-${var.environment}-slack-webhook"
  kms_key_id = var.secrets_kms_key_arn

  tags = var.tags
}

# NOTE: the actual webhook value is intentionally NOT set here.
# Populate it out-of-band after apply, e.g.:
#   aws secretsmanager put-secret-value \
#     --secret-id irs-dev-slack-webhook \
#     --secret-string '{"webhook_url":"https://hooks.slack.com/services/..."}'
# This keeps the real webhook out of Terraform state entirely.

# =====================================================
# SLACK NOTIFIER LAMBDA
# =====================================================

data "archive_file" "slack_notifier" {
  count = var.enable_slack_alerts ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/src/slack_notifier"
  output_path = "${path.module}/.build/slack_notifier.zip"
}

resource "aws_iam_role" "slack_notifier" {
  count = var.enable_slack_alerts ? 1 : 0
  name  = "${var.project_name}-${var.environment}-slack-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "slack_notifier" {
  count = var.enable_slack_alerts ? 1 : 0
  name  = "${var.project_name}-${var.environment}-slack-notifier-policy"
  role  = aws_iam_role.slack_notifier[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.slack_webhook[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.secrets_kms_key_arn
      }
    ]
  })
}

resource "aws_lambda_function" "slack_notifier" {
  count = var.enable_slack_alerts ? 1 : 0

  function_name = "${var.project_name}-${var.environment}-slack-notifier"
  description   = "Forwards incident response SNS alerts to Slack via incoming webhook."
  role          = aws_iam_role.slack_notifier[0].arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_seconds

  filename         = data.archive_file.slack_notifier[0].output_path
  source_code_hash = data.archive_file.slack_notifier[0].output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      SLACK_WEBHOOK_SECRET_ARN = aws_secretsmanager_secret.slack_webhook[0].arn
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
  count = var.enable_slack_alerts ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.slack_notifier[0].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.sns_kms_key_arn

  tags = var.tags
}

resource "aws_sns_topic_subscription" "slack" {
  count = var.enable_slack_alerts ? 1 : 0

  topic_arn = aws_sns_topic.incident_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}

resource "aws_lambda_permission" "allow_sns" {
  count = var.enable_slack_alerts ? 1 : 0

  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.incident_alerts.arn
}
