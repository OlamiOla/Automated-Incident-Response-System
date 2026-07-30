package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestDetectionModule validates the detection module in isolation using
// mocked dependency ARNs rather than chaining every upstream module —
// keeps this test fast since detection has the most resources to create.
func TestDetectionModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../modules/detection",
		Vars: map[string]interface{}{
			"project_name":             "irs",
			"environment":              "test",
			"kms_key_arn":              "arn:aws:kms:us-east-1:657024676280:key/mock",
			"log_archive_bucket_name":  "irs-test-log-archive-657024676280",
			"log_archive_bucket_arn":   "arn:aws:s3:::irs-test-log-archive-657024676280",
			"enable_cloudtrail":        true,
			"enable_guardduty":         true,
			"enable_aws_config":        false, // skip Config in tests: account-wide singleton, conflicts across parallel test runs
			"enable_vpc_flow_logs":     false, // no VPC available in isolated test context
			"enable_security_hub":      false, // account-wide singleton, same reasoning as Config
			"eventbridge_target_arns": map[string]interface{}{
				"disable_iam_key": "arn:aws:states:us-east-1:657024676280:stateMachine:mock-disable",
				"quarantine_s3":    "arn:aws:states:us-east-1:657024676280:stateMachine:mock-quarantine",
				"revoke_session":   "arn:aws:states:us-east-1:657024676280:stateMachine:mock-revoke",
			},
			"eventbridge_target_role_arn": "arn:aws:iam::657024676280:role/mock-eventbridge-role",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	cloudtrailArn := terraform.Output(t, terraformOptions, "cloudtrail_arn")
	guarddutyId := terraform.Output(t, terraformOptions, "guardduty_detector_id")

	assert.Contains(t, cloudtrailArn, "arn:aws:cloudtrail:")
	assert.NotEmpty(t, guarddutyId)
}
