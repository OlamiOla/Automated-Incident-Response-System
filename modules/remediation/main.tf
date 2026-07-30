data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  functions = {
    disable_iam_key = {
      enabled     = var.enable_disable_iam_key_action
      description = "Disables an IAM access key flagged as compromised or leaked."
      handler     = "handler.lambda_handler"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["iam:UpdateAccessKey", "iam:GetAccessKeyLastUsed"]
            Resource = "arn:aws:iam::*:user/*"
          }
        ]
      })
    }

    quarantine_s3 = {
      enabled     = var.enable_quarantine_s3_action
      description = "Applies a deny-all bucket policy to an S3 bucket flagged as publicly exposed."
      handler     = "handler.lambda_handler"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock", "s3:GetBucketPolicy"]
            Resource = "arn:aws:s3:::*"
          }
        ]
      })
    }

    revoke_session = {
      enabled     = var.enable_revoke_session_action
      description = "Revokes active sessions for a user by attaching a deny-all policy scoped to the session's start time."
      handler     = "handler.lambda_handler"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["iam:PutUserPolicy", "iam:GetUserPolicy"]
            Resource = "arn:aws:iam::*:user/*"
          }
        ]
      })
    }
  }
}

# =====================================================
# LAMBDA PACKAGES — zipped from src/<function_key>/
# =====================================================

data "archive_file" "function" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  type        = "zip"
  source_dir  = "${path.module}/src/${each.key}"
  output_path = "${path.module}/.build/${each.key}.zip"
}

# =====================================================
# SQS — DEAD LETTER QUEUES
# =====================================================

resource "aws_sqs_queue" "dlq" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name                              = "${var.project_name}-${var.environment}-${each.key}-dlq"
  message_retention_seconds         = 1209600 # 14 days
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = var.tags
}

# =====================================================
# IAM — PER-FUNCTION LEAST-PRIVILEGE ROLES
# =====================================================

resource "aws_iam_role" "function" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name = "${var.project_name}-${var.environment}-${each.key}-role"

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

resource "aws_iam_role_policy" "function_action" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name   = "${var.project_name}-${var.environment}-${each.key}-action-policy"
  role   = aws_iam_role.function[each.key].id
  policy = each.value.policy
}

resource "aws_iam_role_policy" "function_common" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name = "${var.project_name}-${var.environment}-${each.key}-common-policy"
  role = aws_iam_role.function[each.key].id

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
        Action   = ["dynamodb:PutItem"]
        Resource = var.incident_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.dlq[each.key].arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =====================================================
# LAMBDA FUNCTIONS
# =====================================================

resource "aws_lambda_function" "function" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  function_name = "${var.project_name}-${var.environment}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.function[each.key].arn
  handler       = each.value.handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  filename         = data.archive_file.function[each.key].output_path
  source_code_hash = data.archive_file.function[each.key].output_base64sha256

  kms_key_arn = var.kms_key_arn

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq[each.key].arn
  }

  environment {
    variables = {
      INCIDENT_TABLE_NAME = var.incident_table_name
      SNS_TOPIC_ARN       = var.sns_topic_arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "function" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name              = "/aws/lambda/${aws_lambda_function.function[each.key].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "function_errors" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.lambda_error_alarm_threshold
  alarm_description   = "Remediation Lambda ${each.key} failed to execute successfully."
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.function[each.key].function_name
  }

  tags = var.tags
}

# =====================================================
# STEP FUNCTIONS — INCIDENT RESPONSE PLAYBOOKS
# =====================================================

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "step_functions_invoke" {
  name = "${var.project_name}-${var.environment}-step-functions-invoke-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [for f in aws_lambda_function.function : f.arn]
    }]
  })
}

resource "aws_sfn_state_machine" "playbook" {
  for_each = { for k, v in local.functions : k => v if v.enabled }

  name     = "${var.project_name}-${var.environment}-${each.key}-playbook"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Incident response playbook for ${each.key}"
    StartAt = "Remediate"
    States = {
      Remediate = {
        Type     = "Task"
        Resource = aws_lambda_function.function[each.key].arn
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 5
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "RemediationFailed"
        }]
        End = true
      }
      RemediationFailed = {
        Type  = "Fail"
        Error = "RemediationFailed"
        Cause = "The remediation Lambda failed after retries."
      }
    }
  })

  tags = var.tags
}

# =====================================================
# IAM — EVENTBRIDGE INVOKE ROLE (used by detection module)
# =====================================================

resource "aws_iam_role" "eventbridge_invoke" {
  name = "${var.project_name}-${var.environment}-eventbridge-invoke-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_invoke" {
  name = "${var.project_name}-${var.environment}-eventbridge-invoke-policy"
  role = aws_iam_role.eventbridge_invoke.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [for sm in aws_sfn_state_machine.playbook : sm.arn]
    }]
  })
}
