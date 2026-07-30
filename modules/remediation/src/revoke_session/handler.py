import boto3
import os
import json
import datetime

iam = boto3.client("iam")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

REVOKE_POLICY_NAME = "IRS-SessionRevocation"


def lambda_handler(event, context):
    detail = event.get("detail", {})
    user_identity = detail.get("userIdentity", {})
    user_name = user_identity.get("userName", "unknown")
    revoke_time = datetime.datetime.utcnow().isoformat() + "Z"

    deny_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "DenyIfCredentialsIssuedBeforeRevocation",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "DateLessThan": {"aws:TokenIssueTime": revoke_time}
            }
        }]
    }

    action_taken = "no_action"
    if user_name != "unknown":
        iam.put_user_policy(
            UserName=user_name,
            PolicyName=REVOKE_POLICY_NAME,
            PolicyDocument=json.dumps(deny_policy)
        )
        action_taken = "session_revoked"

    table = dynamodb.Table(os.environ["INCIDENT_TABLE_NAME"])
    table.put_item(Item={
        "incident_id": context.aws_request_id,
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "resource_arn": f"arn:aws:iam::user/{user_name}",
        "action_taken": action_taken,
        "finding_type": "root_account_login",
    })

    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Subject="Incident Response: Session revoked",
        Message=f"Active sessions for {user_name} revoked as of {revoke_time}. Action: {action_taken}"
    )
    return {"status": "ok", "action_taken": action_taken}
