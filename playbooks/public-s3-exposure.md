# Playbook: Publicly Exposed S3 Bucket

## Trigger
AWS Config rule `s3-bucket-public-read-prohibited` or
`s3-bucket-public-write-prohibited` transitions to `NON_COMPLIANT`.

## Automated Response
1. **Detection** — AWS Config evaluates the bucket's ACL/policy on change and
   flags non-compliance.
2. **Routing** — EventBridge rule `irs-<env>-s3-public-exposure` matches the
   compliance change event and starts the `quarantine_s3` Step Functions execution.
3. **Remediation** — the `quarantine_s3` Lambda:
   - Applies a deny-all bucket policy (blocks all principals, all actions).
   - Enables S3 Block Public Access at the bucket level.
4. **Logging** — incident recorded with the bucket name and the specific Config
   rule that triggered.
5. **Alerting** — SNS notifies on all channels.

## Manual Follow-Up (required)
1. Determine why the bucket became public — check CloudTrail for the specific
   `PutBucketPolicy` / `PutBucketAcl` call and who/what made it.
2. If the bucket is meant to be public (e.g. static website hosting, public
   downloads): this is a **false positive by design**. Add the bucket to an
   exclusion list in the Config rule scope, and manually reverse the
   quarantine once confirmed safe.
3. If unintended: review what data was in the bucket and how long it was
   exposed (check `log_archive` for S3 access logs during the exposure window).
   Depending on data sensitivity, this may require a formal data breach
   assessment.
4. Identify the root cause (manual console change? Terraform drift? a
   misconfigured CI/CD pipeline?) and fix the source, not just the symptom.

## False Positive Handling
Static websites, public asset buckets, and similar intentionally-public buckets
should be tagged (e.g. `PublicByDesign = true`) and excluded from the Config
rule's scope going forward, rather than manually un-quarantined after every
deploy.
