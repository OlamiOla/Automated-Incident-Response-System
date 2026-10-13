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

## Repository Structure

```
.
├── root.hcl                  # Terragrunt root config — provider, backend, common tags
├── backend.hcl               # S3 backend bucket/region
├── account.hcl               # AWS account ID
├── region.hcl                # AWS region
├── env/
│   ├── dev/env.hcl           # Dev-specific variables (vpc_id, alert emails, etc.)
│   └── prod/env.hcl          # Prod-specific variables
├── live/
│   ├── dev/                  # Terragrunt units for dev (kms, logging, alerting, remediation, detection)
│   └── prod/                 # Terragrunt units for prod
├── modules/
│   ├── kms/                  # KMS CMK resources
│   ├── logging/              # S3 archive + DynamoDB incident table
│   ├── alerting/             # SNS + Slack notifier Lambda
│   ├── remediation/          # Remediation Lambdas + Step Functions
│   └── detection/            # CloudTrail, GuardDuty, Config, Security Hub, EventBridge
├── playbooks/                # Human-readable incident response runbooks
├── test/                     # Terratest integration tests
└── .github/workflows/        # CI/CD pipelines
```

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

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TG_ENVIRONMENT` | Yes | Deployment target — `dev` or `prod`. Selects `env/<value>/env.hcl`. |
| `AWS_PROFILE` | No | AWS CLI profile to use, if not using the default. |
| `TG_SKIP_DEPENDENCY_OUTPUTS` | No | Set to `true` to use mock dependency outputs instead of reading real state. Only safe for `init`. |
| `AWS_REGION` | No | Overrides the region in `region.hcl` if needed. |

---

## Destroying Infrastructure

Destroy an environment by running `destroy` in reverse dependency order (detection → remediation → alerting → logging → kms), or let Terragrunt handle ordering automatically:

```bash
export TG_ENVIRONMENT=dev
cd live/dev
terragrunt run --all -- destroy
```

> **Warning:** Destroying prod will delete all incident logs from DynamoDB and remove the S3 log archive. The S3 bucket uses object-lock COMPLIANCE mode — objects within the retention window cannot be deleted even by the account root user. Plan retention periods carefully before deploying.

---

## Adding a KICS Suppression

If KICS flags a finding that is a known false positive or an accepted risk, suppress it rather than disabling the rule globally:

1. Find the query ID in the KICS JSON report (`queries[].id`).
2. Add it to `.kics/config.yml` under `exclude-queries`:
   ```yaml
   exclude-queries:
     - "your-query-id-here"
   ```
3. Document the justification in `.kics/suppressions.md` with:
   - The query ID and name
   - Why it is a false positive or accepted risk
   - Date added and who approved it

Never suppress a MEDIUM, HIGH, or CRITICAL finding without a documented justification — the CI pipeline will reject undocumented suppressions during code review.

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

Two GitHub Actions workflows trigger on push to `main`/`airsys` and on pull requests targeting `main`. Both run **without real AWS credentials** — dummy credentials are injected so the provider can initialise, and `-backend=false` + `TG_SKIP_DEPENDENCY_OUTPUTS=true` bypass the S3 backend and cross-module state reads.

This validates syntax, provider schema, and most configuration errors without requiring an AWS account. Data sources that call AWS APIs will show errors in the plan output — this is expected and does not indicate a real problem.

### `terragrunt-plan.yml` — Plan (dev)
1. KICS security scan (build from pinned source, fail on MEDIUM/HIGH/CRITICAL)
2. `terragrunt run --all -- init -backend=false`
3. `terragrunt run --all -- plan -lock=false -input=false`
4. Uploads plan output as a workflow artifact

### `terragrunt-apply.yml` — Plan (prod) + Apply (disabled)
1. KICS security scan
2. `terragrunt run --all -- init -backend=false`
3. `terragrunt run --all -- plan -lock=false -input=false`
4. **Apply job is disabled** (`if: false`) until AWS OIDC is configured

### Enabling real Apply

When you are ready to deploy from CI:

1. Configure the GitHub OIDC trust policy on your IAM role (see Troubleshooting → OIDC).
2. Set `AWS_ROLE_ARN` and `AWS_REGION` as repository variables in GitHub Settings → Variables.
3. In `terragrunt-apply.yml`, remove the `if: false` line from the `apply` job.
4. Configure required reviewers on the `production` environment in GitHub Settings → Environments.

> **Important:** This system can disable IAM keys and modify S3 bucket policies in response to real findings. Do not enable the apply job without the production environment protection rules in place.

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


---

## Troubleshooting

### `flag -upgrade is not a Terragrunt flag`

Terragrunt 1.x requires a `--` separator between Terragrunt flags and Terraform flags. Any flag intended for Terraform must come after `--`:

```bash
# Wrong
terragrunt run --all init -upgrade

# Correct
terragrunt run --all -- init -upgrade
```

---

### `no available releases match the given constraints ~> 6.60`

The `~> 6.60` constraint is interpreted as "≥ 6.60.0 and < 7.0.0". If your Terraform binary or registry mirror cannot resolve that, broaden the constraint in `root.hcl` to `~> 6.0` (any 6.x release) and re-run `init -upgrade`.

---

### `InvalidClientTokenId: The security token included in the request is invalid`

Your AWS credentials are expired or not configured. Fix before running any init/plan/apply:

```bash
# Verify credentials are working
aws sts get-caller-identity

# If using SSO
aws sso login --profile <your-profile>
export AWS_PROFILE=<your-profile>

# If using static keys
aws configure
```

---

### `Backend initialization required` when running `init -backend=false`

Running `init -backend=false` skips the S3 backend. Downstream units that depend on outputs from an upstream unit will then fail when Terragrunt tries to run `terraform output -json` against a backend-less working directory.

Fix: pass `TG_SKIP_DEPENDENCY_OUTPUTS=true` so Terragrunt uses mock outputs instead of reading real state:

```bash
TG_SKIP_DEPENDENCY_OUTPUTS=true terragrunt run --all -- init -upgrade -backend=false
```

This is safe for lock file regeneration. Do **not** use it for plan or apply — real outputs are required for those.

---

### `There is no variable named "dependency"` during init

This happens when Terragrunt cannot resolve a `dependency` block's outputs (e.g. the upstream unit's backend is not initialized) and the current command is not listed in `mock_outputs_allowed_terraform_commands`.

The dependency blocks in `live/*/terragrunt.hcl` include `"init-upgrade"` in `mock_outputs_allowed_terraform_commands` and a `skip_outputs` toggle for this reason. If you add a new dependency block, follow the same pattern:

```hcl
dependency "example" {
  config_path  = "../example"
  skip_outputs = tobool(get_env("TG_SKIP_DEPENDENCY_OUTPUTS", "false"))

  mock_outputs = {
    some_output = "mock-value"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "init-upgrade"]
}
```

---

### Terratest: `go test` fails with import errors after upgrading Terratest

Terratest v1.0.1 (the current pin) is API-compatible with v0.x for the functions used in this repo. If you upgrade to v2.x in the future, all import paths change to `/v2` suffixes and Go 1.26+ is required. See the [Terratest v2 migration guide](https://terratest.gruntwork.io/docs/migrating-to-v2/overview/) before upgrading.

---

### KICS scan: `No KICS results file found`

This usually means the `kics scan` command exited non-zero before writing output (the workflow uses `|| true` so it does not fail the step). Check the "Run KICS scan" step logs for the actual error. Common causes:

- `--config` path is wrong — verify `.kics/config.yml` exists at the repo root
- `--path` has no `.tf` files — verify the `modules/` directory is populated after checkout
- Build failure in the "Build KICS from pinned source commit" step — check Go version compatibility

---

### Slack notifications not arriving

1. Verify the webhook secret is populated:
   ```bash
   aws secretsmanager get-secret-value --secret-id irs-<env>-slack-webhook
   ```
2. Check the `slack-notifier` Lambda logs in CloudWatch (`/aws/lambda/irs-<env>-slack-notifier`) for HTTP error codes from Slack.
3. Check the SQS DLQ (`irs-<env>-slack-notifier-dlq`) — failed invocations land there for inspection.
