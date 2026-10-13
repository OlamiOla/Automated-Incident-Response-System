# Automated Incident Response System

Detects suspicious AWS activity via GuardDuty, CloudTrail, and AWS Config, then automatically remediates using Step Functions–orchestrated Lambda playbooks.

---

## Architecture

```
CloudTrail / GuardDuty / AWS Config
         │
         ▼
    EventBridge Rules
         │
         ▼
  Step Functions Playbook
         │
         ▼
  Remediation Lambda ──► DynamoDB (incident log)
         │
         ▼
     SNS Topic ──► Email / SMS / Slack
```

**Modules**

| Module | Purpose |
|--------|---------|
| `kms` | Customer-managed keys for CloudTrail, DynamoDB, SNS, Secrets Manager |
| `logging` | S3 log archive, DynamoDB incident table |
| `alerting` | SNS topic, Slack notifier Lambda |
| `remediation` | Lambda functions + Step Functions playbooks |
| `detection` | CloudTrail, GuardDuty, AWS Config, Security Hub, VPC Flow Logs, EventBridge rules |

---

## Prerequisites

| Tool | Required version |
|------|-----------------|
| Terraform | ≥ 1.16 |
| Terragrunt | ≥ 1.1 |
| Go | ≥ 1.22 (Terratest) |
| AWS CLI | any recent version |

AWS credentials must be configured for account `657024676280` before running any Terragrunt commands.

An S3 bucket (`dev-sec-git-repo-s3`) and DynamoDB table (`dev-terraform-lock-config`) for Terraform remote state must already exist — they are referenced via `backend.hcl` and are not created by this repo.

---

## First-Time Setup

1. **Fill in environment-specific values.**

   `env/dev/env.hcl` and `env/prod/env.hcl` contain placeholders that must be replaced before deploying:
   - `vpc_id` — required if `enable_vpc_flow_logs = true`
   - `alert_email_addresses` / `alert_sms_numbers` — who receives incident alerts

2. **Deploy, environment by environment:**

```bash
export TG_ENVIRONMENT=dev
cd live/dev
terragrunt run --all -- plan
terragrunt run --all -- apply
```

   Repeat with `TG_ENVIRONMENT=prod` and `cd live/prod` for production.

3. **Populate the Slack webhook** (created empty by Terraform — the real value is intentionally never stored in Terraform state):

```bash
aws secretsmanager put-secret-value \
  --secret-id irs-dev-slack-webhook \
  --secret-string '{"webhook_url":"https://hooks.slack.com/services/YOUR/WEBHOOK/URL"}'
```

   Repeat with `irs-prod-slack-webhook` for production.

---

## Testing

Run the Terratest suite (creates and destroys real AWS resources — expect several minutes and small, short-lived AWS charges):

```bash
cd test
go mod tidy
go test -v -timeout 30m ./...
```

Run the KICS security scan locally before pushing:

```bash
kics scan \
  --path modules/ \
  --config .kics/config.yml \
  --report-formats json
```

Test a remediation Lambda locally against a sample event without deploying:

```bash
aws lambda invoke \
  --function-name irs-dev-disable_iam_key \
  --payload file://test/fixtures/sample_guardduty_finding.json \
  response.json
```

---

## CI/CD

Two GitHub Actions workflows trigger on push to `main`/`airsys` and on pull requests targeting `main`:

### `terragrunt-plan.yml` — Plan (dev)
1. KICS security scan (build from pinned source, fail on MEDIUM/HIGH/CRITICAL)
2. `terragrunt run --all -- init`
3. `terragrunt run --all -- plan -lock=false`
4. Uploads plan output as a workflow artifact

### `terragrunt-apply.yml` — Apply (prod)
1. KICS security scan
2. `terragrunt run --all -- init`
3. `terragrunt run --all -- plan -lock=false`
4. `terragrunt run --all -- apply -auto-approve` *(main branch, non-PR only)*
5. Slack notification on completion

> **Important:** This system can disable IAM keys and modify S3 bucket policies in response to real findings. Configure required reviewers on the `production` environment in GitHub Settings → Environments before relying on the apply workflow for live infrastructure.

---

## Updating Lock Files

After changing the AWS provider version constraint in `root.hcl`, regenerate the lock files in each environment. This requires valid AWS credentials or can be done without a backend connection using:

```bash
cd live/dev
TG_SKIP_DEPENDENCY_OUTPUTS=true terragrunt run --all -- init -upgrade -backend=false

cd live/prod
TG_SKIP_DEPENDENCY_OUTPUTS=true terragrunt run --all -- init -upgrade -backend=false
```

Commit the updated `.terraform.lock.hcl` files.

---

## Incident Response Playbooks

See `playbooks/` for the human-readable runbook per scenario — what is automated, what still requires manual judgment, and how to handle false positives:

- [`compromised-iam-key.md`](playbooks/compromised-iam-key.md)
- [`root-account-login.md`](playbooks/root-account-login.md)
- [`public-s3-exposure.md`](playbooks/public-s3-exposure.md)
- [`unusual-network-activity.md`](playbooks/unusual-network-activity.md)

---

## Security Notes

- All data at rest (CloudTrail logs, DynamoDB, SNS, Secrets Manager) is encrypted with dedicated customer-managed KMS keys.
- Lambda functions run with least-privilege IAM roles scoped per function.
- The Slack webhook URL is stored in Secrets Manager and never written to Terraform state.
- The KICS scan in CI builds from a pinned source commit SHA — no Docker Hub images are used.
- S3 log archive enforces TLS-only access, KMS encryption on upload, and object-lock COMPLIANCE mode retention.
