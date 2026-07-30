package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestKMSModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../modules/kms",
		Vars: map[string]interface{}{
			"project_name":              "irs",
			"environment":               "test",
			"key_deletion_window_days":  7,
			"enable_key_rotation":       true,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	logsKeyArn := terraform.Output(t, terraformOptions, "logs_key_arn")
	dynamodbKeyArn := terraform.Output(t, terraformOptions, "dynamodb_key_arn")
	snsKeyArn := terraform.Output(t, terraformOptions, "sns_key_arn")
	secretsKeyArn := terraform.Output(t, terraformOptions, "secrets_key_arn")

	assert.Contains(t, logsKeyArn, "arn:aws:kms:")
	assert.Contains(t, dynamodbKeyArn, "arn:aws:kms:")
	assert.Contains(t, snsKeyArn, "arn:aws:kms:")
	assert.Contains(t, secretsKeyArn, "arn:aws:kms:")
}
