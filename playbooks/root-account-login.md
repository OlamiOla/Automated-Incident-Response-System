# Playbook: Root Account Login

## Trigger
CloudTrail event `AWS Console Sign In via CloudTrail` where `userIdentity.type = Root`.
Root logins should be rare — most organizations avoid using the root account for
day-to-day operations entirely.

## Automated Response
1. **Detection** — CloudTrail records the sign-in event; EventBridge rule
   `irs-<env>-root-login` matches it immediately.
2. **Routing** — the `revoke_session` Step Functions execution starts.
3. **Remediation** — the `revoke_session` Lambda attaches a time-boxed deny-all
   policy to the account, invalidating any session token issued before the
   revocation timestamp (`aws:TokenIssueTime` condition).
4. **Logging** — incident recorded with the login timestamp and source IP.
5. **Alerting** — this triggers a **CRITICAL**-severity alert on all channels
   (email, SMS, and Slack) regardless of configured severity threshold, since
   root logins are inherently high-risk.

## Manual Follow-Up (required)
1. **Immediately verify** with your team whether this was an expected, planned
   root login (e.g. a billing task requiring root, per AWS's documented list
   of root-only actions).
2. If unexpected: treat as a confirmed incident.
   - Rotate the root account password immediately.
   - Verify and rotate MFA device registration.
   - Review CloudTrail for all actions taken during the root session.
   - Check for new IAM users, access keys, or policy changes created during
     the session — these are common persistence techniques.
3. If expected: document the reason in the incident record and consider
   whether the task could be delegated to an IAM role instead going forward,
   to avoid future root usage.

## Prevention Note
Long-term, enable an SCP (Service Control Policy) at the AWS Organizations level
that blocks all root actions except account recovery — this playbook exists as
a safety net, not a substitute for eliminating root usage.
