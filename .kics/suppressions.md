# KICS Suppressions

Every query ID excluded in `config.yml` must have an entry here explaining
why. This file is the audit trail for security-scan exceptions — if a
reviewer or auditor asks "why is this flagged issue allowed to exist," this
document is the answer.

Do not add a suppression without team review. Do not suppress a finding
just to make CI pass — fix the underlying issue unless there's a genuine,
documented reason it can't be fixed.

---

## Query: IAM policy allows write actions without constraints
**ID:** `12ed526f-2f75-4c96-b83c-2dd0c8b47b76`

**Where:** `modules/remediation/main.tf` — `aws_iam_role_policy.function_action`
for `disable_iam_key`, `quarantine_s3`, and `revoke_session`.

**Why suppressed:** These are the core remediation actions this system
exists to perform. `disable_iam_key` legitimately needs
`iam:UpdateAccessKey` write access; `quarantine_s3` legitimately needs
`s3:PutBucketPolicy` write access; `revoke_session` legitimately needs
`iam:PutUserPolicy` write access. Flagging "unconstrained write" is
expected for a remediation system by design — the actual control is that
each policy's `Resource` is scoped to `arn:aws:iam::*:user/*` or
`arn:aws:s3:::*` (not `*` across all services), and each function's IAM
role has no permissions outside its single action.

**Compensating control:** Least-privilege role-per-function (see
`modules/remediation/main.tf`, `aws_iam_role.function`) — no function can
perform another function's action, even though each individually needs
write access to do its job.

**Reviewed by:** _pending — add reviewer name + date on first real review_

---

## Query: IAM policy has wildcard resource
**ID:** `1e434b58-e0b7-4a5c-9c1f-5f30a2f6a1c9`

**Where:** `modules/remediation/main.tf` — `disable_iam_key` and
`revoke_session` policies use `arn:aws:iam::*:user/*` (wildcard on account
ID and username, not a bare `*`).

**Why suppressed:** These policies intentionally target "any IAM user in
this account" because the remediation Lambda doesn't know in advance which
user will be compromised — that's the entire point of an automated
responder. The wildcard is scoped to the resource *type* (IAM users), not
to all AWS resources.

**Compensating control:** Scoped to `iam::*:user/*`, never a bare `"*"`.
Combined with CloudTrail logging every invocation and DynamoDB recording
every action taken, so wildcard usage is always auditable after the fact.

**Reviewed by:** _pending_

---

## Query: SNS topic policy allows service principal without explicit source ARN condition
**ID:** `8d7f5065-8c66-4d5c-9e37-3fb99d38c5c7`

**Where:** `modules/alerting/main.tf` — `aws_sns_topic_policy.incident_alerts`,
statement `AllowCloudWatchAlarmPublish`.

**Why suppressed:** The statement grants `sns:Publish` to the
`cloudwatch.amazonaws.com` service principal. KICS flags this because it
isn't scoped with a `Condition` block tying it to a specific source ARN.
This is standard, required practice for CloudWatch Alarms to publish to
SNS — the `Principal` is an AWS service, not an open/anonymous principal.

**Compensating control:** A separate statement (`DenyInsecureTransport`) in
the same policy denies any publish attempt over non-TLS transport, and the
topic itself is scoped to this project's alarms only via the
`aws_cloudwatch_metric_alarm.function_errors` resource, not exposed
externally.

**Reviewed by:** _pending_

---

## How to add a new suppression

1. Confirm the finding is a genuine false positive or an accepted risk with
   a compensating control — not just inconvenient to fix.
2. Add the query ID to `config.yml` under `exclude-queries`, with an inline
   comment pointing back to this file.
3. Add a matching entry here: where it applies, why it's suppressed, what
   compensates for it, and who reviewed it.
4. Get sign-off from whoever owns security review before merging.

