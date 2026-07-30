package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestLoggingModule(t *testing.T) {
	t.Parallel()

	// kms module must apply first to provide real key ARNs
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
	dynamodbKeyArn := terraform.Output(t, kmsOptions, "dynamodb_key_arn")

	uniqueSuffix := random.UniqueId()
	bucketName := "irs-test-log-archive-" + uniqueSuffix

	loggingOptions := &terraform.Options{
		TerraformDir: "../modules/logging",
		Vars: map[string]interface{}{
			"project_name":             "irs",
			"environment":              "test",
			"kms_key_arn":              logsKeyArn,
			"dynamodb_kms_key_arn":     dynamodbKeyArn,
			"log_archive_bucket_name":  bucketName,
			"log_archive_glacier_days": 30,
			"cloudtrail_account_id":    "657024676280",
			"incident_table_name":      "incidents",
		},
	}

	defer terraform.Destroy(t, loggingOptions)
	terraform.InitAndApply(t, loggingOptions)

	actualBucketName := terraform.Output(t, loggingOptions, "log_archive_bucket_name")
	tableName := terraform.Output(t, loggingOptions, "incident_table_name")

	assert.Equal(t, bucketName, actualBucketName)
	assert.Contains(t, tableName, "incidents")
}
