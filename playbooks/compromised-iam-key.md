# Playbook: Compromised IAM Access Key

## Trigger
GuardDuty finding type `UnauthorizedAccess:IAMUser*` (e.g. credential exfiltration,
anomalous API calls from an unfamiliar location, or use of a key associated with
known malicious infrastructure).

## Automated Response
1. **Detection** — GuardDuty publishes the finding to EventBridge.
2. **Routing** — EventBridge rule `irs-<env>-guardduty-finding` matches the finding
   and starts the `disable_iam_key` Step Functions execution.
3. **Remediation** — the `disable_iam_key` Lambda calls
   `iam:UpdateAccessKey` to set the key's status to `Inactive`.
4. **Logging** — an incident record is written to DynamoDB with the access key ARN,
   timestamp, and action taken.
5. **Alerting** — SNS publishes to email/SMS/Slack confirming the key was disabled.

## Manual Follow-Up (required — automation does not do this)
1. Confirm with the key owner whether the activity was legitimate or malicious.
2. If malicious: rotate all other credentials belonging to that IAM user.
3. Review CloudTrail for that access key's full activity history
   (`aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<key>`).
4. If the key was used to create new resources (e.g. new IAM users, EC2 instances),
   inventory and remove anything unauthorized.
5. Once confirmed safe, either delete the key permanently or reactivate it
   (`iam:UpdateAccessKey` back to `Active`) if it was a false positive.
6. Update the incident record in DynamoDB with the final resolution.

## False Positive Handling
If this was legitimate activity (e.g. a new CI/CD pipeline using the key from a
new IP range), reactivate the key and consider adding the source to GuardDuty's
trusted IP list to reduce future noise.
