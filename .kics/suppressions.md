# KICS Suppressions

Every query ID excluded in `config.yml` must have an entry here explaining
why. Do not suppress a finding just to make CI pass — fix the underlying
issue unless there's a genuine, documented reason it can't be fixed.

---

## Query: KMS Key With Vulnerable Policy
**ID:** `7ebc9038-0bde-479a-acc4-6ed7b6758899`

**Where:** `modules/kms/main.tf` — all four CMKs (`logs`, `dynamodb`, `sns`,
`secrets`), statement `EnableRootAccountAdmin`.

**Why suppressed:** KICS flags `Action = "kms:*"` as a wildcard. This
statement grants the AWS account root full key administration — the
standard, AWS-documented pattern for every CMK, since without it a change
to IAM policies could permanently lock the account out of its own key.
The `Principal` is scoped to `arn:aws:iam::<this account>:root`, not `*`.

**Compensating control:** Principal is account-scoped, not open. All other
statements in each key policy are scoped to specific AWS service
principals with specific actions, not wildcards.

**Reviewed by:** _pending_

---

## Query: CloudTrail SNS Topic Name Undefined
**ID:** `482b7d26-0bdb-4b5f-bf6f-545826c0a3dd`

**Where:** `modules/detection/main.tf` — `aws_cloudtrail.main`.

**Why suppressed:** This checks for CloudTrail's native log-delivery SNS
notification. This project's actual incident alerting runs through a
separate, deliberate path — GuardDuty/Config findings → EventBridge →
Step Functions → SNS (see `modules/alerting`) — not through CloudTrail's
own delivery notifications. Wiring a second, unused SNS topic solely to
satisfy this check adds an unmonitored resource rather than real coverage.

**Reviewed by:** _pending_

---

## Note (not suppressed, informational only): Resource Not Using Tags
**ID:** `e38a8e0a-b88b-4902-b3fe-b0fcb17d5c10` (INFO severity — excluded
from the report via `exclude-severities: [INFO]` in config.yml, not via
exclude-queries)

Every resource in this project sets `tags = var.tags`, which resolves to
`common_tags` (Project, Environment, ManagedBy) defined in `root.hcl`.
KICS's static analysis can't resolve variable contents, so it can't
confirm tags exist beyond `Name` — a known limitation of variable-based
tagging, not an actual gap. No action needed.

---

## How to add a new suppression

1. Confirm the finding is a genuine false positive or an accepted risk
   with a compensating control — not just inconvenient to fix.
2. Add the query ID to `config.yml` under `exclude-queries`, with an
   inline comment pointing back to this file.
3. Add a matching entry here: where it applies, why it's suppressed,
   what compensates for it, and who reviewed it.
4. Get sign-off from whoever owns security review before merging.

---

## Query: S3 Bucket Without Enabled MFA Delete
**ID:** `c5b31ab9-0f26-4a49-b8aa-4cc064392f4d`

**Where:** `modules/logging/main.tf` — `aws_s3_bucket_versioning.log_archive`.

**Why suppressed:** KICS's own finding description confirms MFA Delete
cannot be enabled through Terraform — it requires a manual AWS CLI command
with a physical or virtual MFA device attached to the account.

**Manual step (not automated by this project):** After first apply, an
account admin should run:
aws s3api put-bucket-versioning
--bucket <log_archive_bucket_name>
--versioning-configuration Status=Enabled,MFADelete=Enabled
--bucket-owner <account_id>
--mfa "<mfa-serial-number> <mfa-code>"

**Reviewed by:** _pending_

---

## Query: IAM Access Analyzer Not Enabled
**ID:** `e592a0c5-5bdb-414c-9066-5dba7cdea370`

**Where:** flagged once per module file (`kms`, `logging`, `alerting`,
`remediation`, `detection`) — but the analyzer is a single account-level
resource, already created once in `modules/kms/main.tf`
(`aws_accessanalyzer_analyzer.main`).

**Why suppressed:** KICS scans each Terraform file independently and
can't detect that a sibling module already declares this account-wide
resource. Confirmed present and correctly configured in `kms/main.tf`.

**Reviewed by:** _pending_

---

## Query: S3 Bucket Notifications Disabled
**ID:** `e39f87f5-0abf-488b-864c-63ee1f588140`

**Where:** flagged against `aws_sns_topic.incident_alerts`,
`aws_sqs_queue.dlq`, and `aws_lambda_function.function`/`slack_notifier`
— not against the S3 buckets themselves, which appears to be a
resource-attribution quirk in this KICS query.

**Why suppressed:** The underlying suggestion is to wire S3 object-level
events (create/delete) to a notification target. Deliberately not done:
CloudTrail (data events) and AWS Config already audit every operation on
the log archive bucket. Adding S3 event notifications on top would fire
continuously during normal log delivery, flooding the incident-alerts
SNS topic with noise unrelated to actual security findings.

**Reviewed by:** _pending_

---

## Query: S3 Bucket Policy Accepts HTTP Requests
**ID:** `4bc4dd4c-7d8d-405e-a0fb-57fa4c31b4d9`

**Where:** `modules/logging/main.tf` — `aws_s3_bucket_policy.log_archive`
and `aws_s3_bucket_policy.access_logs`, statement `DenyInsecureTransport`
in both.

**Why suppressed:** Both policies already deny all actions over non-TLS
transport, using the exact structure KICS's own documentation lists as
compliant (`Condition.Bool."aws:SecureTransport" = "false"`). This is a
known KICS parser limitation: policies built with `jsonencode({...})`
aren't always fully resolved by this specific query, while the same
structure written as a raw JSON heredoc or via `aws_iam_policy_document`
is recognized correctly. Confirmed via KICS's own documented test cases
and a corresponding open false-positive report
(github.com/Checkmarx/kics/issues/5489).

**Compensating control:** Verified manually — both policies were
reviewed line-by-line against KICS's documented compliant pattern and
match exactly. `jsonencode()` was kept over a raw heredoc for
maintainability (HCL syntax highlighting, trailing-comma safety).

**Reviewed by:** _pending_
