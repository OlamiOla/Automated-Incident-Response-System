# Automated-Incident-Response-System
Detect suspicious activity and automatically respond.
---

## Prerequisites

- Terraform ≥ 1.7
- Terragrunt ≥ 0.58
- Go ≥ 1.22 (for running Terratest)
- Checkov (`pip install checkov`)
- AWS CLI configured with credentials for account `657024676280`
- An existing S3 bucket (`dev-sec-git-repo-s3`) and DynamoDB table
  (`dev-terraform-lock-config`) for Terraform state — already provisioned,
  referenced via `backend.hcl`

---

## First-Time Setup

1. **Fill in environment-specific values.** `env/dev/env.hcl` and
   `env/prod/env.hcl` contain placeholders that must be replaced before
   deploying:
   - `vpc_id` — required if `enable_vpc_flow_logs = true`
   - `alert_email_addresses` / `alert_sms_numbers` — who receives incident alerts

2. **Deploy, environment by environment:**

```bash
   export TG_ENVIRONMENT=dev
   cd live/dev
   terragrunt run-all plan
   terragrunt run-all apply
```

   Repeat with `TG_ENVIRONMENT=prod` and `cd live/prod` for production.

3. **Populate the Slack webhook** (created empty by Terraform — the real
   value is intentionally never stored in Terraform state):

```bash
   aws secretsmanager put-secret-value \
     --secret-id irs-dev-slack-webhook \
     --secret-string '{"webhook_url":"https://hooks.slack.com/services/YOUR/WEBHOOK/URL"}'
```

   Repeat with `irs-prod-slack-webhook` for production.

---

## Testing

Run the Terratest suite (creates and destroys real AWS resources — expect
this to take several minutes and incur small, short-lived AWS charges):

```bash
cd tests
go mod tidy
go test -v -timeout 30m ./...
```

Run the security scan locally before pushing:

```bash
kics scan -p modules/ -c config.yml
```

Test a remediation Lambda locally against a sample event without deploying:

```bash
aws lambda invoke \
  --function-name irs-dev-disable_iam_key \
  --payload file://tests/fixtures/sample_guardduty_finding.json \
  response.json
```

## CI/CD

Both workflows trigger on `pull_request`:

- **Plan** — `terraform fmt -check`, `terragrunt run-all validate`,
  `terragrunt run-all plan`, and a Checkov scan against `config.yml`.
- **Apply** — applies the plan within the same PR pipeline.

Given this system can disable IAM keys and modify S3 bucket policies,
protect the `prod` path in this workflow with required reviewers before
relying on it for real changes.

---

## Incident Response Playbooks

See `playbooks/` for the human-readable runbook per scenario — what's
automated, what still requires manual judgment, and how to handle false
positives:

- [`compromised-iam-key.md`](playbooks/compromised-iam-key.md)
- [`root-account-login.md`](playbooks/root-account-login.md)
- [`public-s3-exposure.md`](playbooks/public-s3-exposure.md)
- [`unusual-network-activity.md`](playbooks/unusual-network-activity.md)
