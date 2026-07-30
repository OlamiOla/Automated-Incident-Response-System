package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestAlertingModule(t *testing.T) {
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

	snsKeyArn := terraform.Output(t, kmsOptions, "sns_key_arn")
	secretsKeyArn := terraform.Output(t, kmsOptions, "secrets_key_arn")

	alertingOptions := &terraform.Options{
		TerraformDir: "../modules/alerting",
		Vars: map[string]interface{}{
			"project_name":           "irs",
			"environment":            "test",
			"sns_kms_key_arn":        snsKeyArn,
			"secrets_kms_key_arn":    secretsKeyArn,
			"alert_email_addresses":  []string{"test-alerts@example.com"},
			"alert_sms_numbers":      []string{},
			"enable_slack_alerts":    true,
		},
	}

	defer terraform.Destroy(t, alertingOptions)
	terraform.InitAndApply(t, alertingOptions)

	topicArn := terraform.Output(t, alertingOptions, "sns_topic_arn")
	secretArn := terraform.Output(t, alertingOptions, "slack_webhook_secret_arn")
	notifierArn := terraform.Output(t, alertingOptions, "slack_notifier_function_arn")

	assert.Contains(t, topicArn, "arn:aws:sns:")
	assert.Contains(t, secretArn, "arn:aws:secretsmanager:")
	assert.Contains(t, notifierArn, "arn:aws:lambda:")
}
