# Playbook: Unusual Network Activity

## Trigger
GuardDuty findings of type `Recon:*`, `UnauthorizedAccess:EC2*`, or
`Trojan:EC2*` — typically derived from VPC Flow Log analysis (port scanning,
communication with known command-and-control IPs, unusual outbound data
volume).

## Automated Response
Note: this scenario currently has detection (GuardDuty + VPC Flow Logs +
Security Hub aggregation) but no dedicated auto-remediation Lambda in this
version of the system — network-layer remediation (e.g. isolating an EC2
instance's security group) carries higher risk of service disruption than
the other three playbooks, so it is intentionally routed to alerting only
for human review rather than fully automated action.

1. **Detection** — GuardDuty analyzes VPC Flow Logs and publishes a finding.
2. **Routing** — Security Hub aggregates the finding; EventBridge can be
   extended to route `Recon:*` / `Trojan:*` types to a dedicated
   `isolate_instance` playbook (see "Future Extension" below).
3. **Alerting** — SNS notifies the security team immediately for manual triage.

## Manual Response (current process)
1. Identify the affected resource (instance ID, ENI, or security group) from
   the GuardDuty finding detail.
2. Check current security group rules and recent changes via CloudTrail.
3. If actively malicious:
   - Isolate the instance by replacing its security group with a
     deny-all/quarantine security group (no inbound, no outbound except to
     a forensics subnet if you have one).
   - Snapshot the EBS volume before any further action, for forensic evidence.
   - Do not terminate the instance immediately — preserve it for investigation.
4. Review VPC Flow Logs for the full timeline of the suspicious traffic.
5. Document findings and remediation steps taken in the incident record
   (manually, since this path isn't Lambda-automated yet).

## Future Extension
To fully automate this playbook, add an `isolate_instance` Lambda to the
`remediation` module (same pattern as `quarantine_s3`) that:
- Calls `ec2:ModifyNetworkInterfaceAttribute` to swap the instance's security
  group to a pre-created quarantine security group (no ingress/egress).
- Optionally creates an EBS snapshot via `ec2:CreateSnapshot` for forensics
  before any further action.
Add a corresponding EventBridge rule in the `detection` module matching
GuardDuty finding types `Recon:*`, `UnauthorizedAccess:EC2*`, `Trojan:EC2*`.
