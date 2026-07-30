package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestRemediationModule(t *testing.T) {
	t.Parallel()

	kmsOptions := &terraform.Options{
		TerraformDir: "../modules/kms",
		Vars: map[string]interface{}{
			"project_name":             "irs",
			"environment":              "test",
			"key_deletion_window_days": 7,
			"enable_key_rotation":      true,
		},
	}
	defer terraform.Destroy(t, kmsOptions)
	terraform.InitAndApply(t, kmsOptions)
	logsKeyArn := terraform.Output(t, kmsOptions, "logs_key_arn")
	snsKeyArn := terraform.Output(t, kmsOptions, "sns_key_arn")
	secretsKeyArn := terraform.Output(t, kmsOptions, "secrets_key_arn")

	loggingOptions := &terraform.Options{
		TerraformDir: "../modules/logging",
		Vars: map[string]interface{}{
			"project_name":             "irs",
			"environment":              "test",
			"kms_key_arn":              logsKeyArn,
			"dynamodb_kms_key_arn":     terraform.Output(t, kmsOptions, "dynamodb_key_arn"),
			"log_archive_bucket_name":  "irs-test-remediation-logs",
			"log_archive_glacier_days": 30,
			"cloudtrail_account_id":    "657024676280",
			"incident_table_name":      "incidents",
		},
	}
	defer terraform.Destroy(t, loggingOptions)
	terraform.InitAndApply(t, loggingOptions)

	alertingOptions := &terraform.Options{
		TerraformDir: "../modules/alerting",
		Vars: map[string]interface{}{
			"project_name":          "irs",
			"environment":           "test",
			"sns_kms_key_arn":       snsKeyArn,
			"secrets_kms_key_arn":   secretsKeyArn,
			"alert_email_addresses": []string{"test-alerts@example.com"},
			"enable_slack_alerts":   false,
		},
	}
	defer terraform.Destroy(t, alertingOptions)
	terraform.InitAndApply(t, alertingOptions)

	remediationOptions := &terraform.Options{
		TerraformDir: "../modules/remediation",
		Vars: map[string]interface{}{
			"project_name":                   "irs",
			"environment":                    "test",
			"kms_key_arn":                    logsKeyArn,
			"incident_table_name":            terraform.Output(t, loggingOptions, "incident_table_name"),
			"incident_table_arn":             terraform.Output(t, loggingOptions, "incident_table_arn"),
			"sns_topic_arn":                  terraform.Output(t, alertingOptions, "sns_topic_arn"),
			"enable_disable_iam_key_action":  true,
			"enable_quarantine_s3_action":    true,
			"enable_revoke_session_action":   true,
		},
	}

	defer terraform.Destroy(t, remediationOptions)
	terraform.InitAndApply(t, remediationOptions)

	playbookArns := terraform.OutputMap(t, remediationOptions, "playbook_arns")
	lambdaArns := terraform.OutputMap(t, remediationOptions, "lambda_function_arns")

	assert.Contains(t, playbookArns, "disable_iam_key")
	assert.Contains(t, playbookArns, "quarantine_s3")
	assert.Contains(t, playbookArns, "revoke_session")
	assert.Contains(t, lambdaArns["disable_iam_key"], "arn:aws:lambda:")
}
