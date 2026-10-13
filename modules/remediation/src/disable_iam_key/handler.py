import boto3
import os
import datetime

iam = boto3.client("iam")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")
sts = boto3.client("sts")


def _get_account_id():
    """Return the current AWS account ID via STS."""
    return sts.get_caller_identity()["Account"]


def lambda_handler(event, context):
    detail = event.get("detail", {})
    access_key_id = detail.get("accessKeyId")
    user_name = detail.get("userName", "unknown")

    action_taken = "no_action"
    if access_key_id:
        iam.update_access_key(
            UserName=user_name,
            AccessKeyId=access_key_id,
            Status="Inactive"
        )
        action_taken = "access_key_disabled"

    account_id = _get_account_id()

    table = dynamodb.Table(os.environ["INCIDENT_TABLE_NAME"])
    table.put_item(Item={
        "incident_id": context.aws_request_id,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "resource_arn": f"arn:aws:iam::{account_id}:user/{user_name}",
        "action_taken": action_taken,
        "finding_type": detail.get("type", "unknown"),
    })

    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Subject="Incident Response: IAM key disabled",
        Message=f"Access key {access_key_id} for user {user_name} was disabled. Action: {action_taken}"
    )
    return {"status": "ok", "action_taken": action_taken}
