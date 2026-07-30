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
