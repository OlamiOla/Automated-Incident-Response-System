import boto3
import os
import json
import datetime

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")


def lambda_handler(event, context):
    detail = event.get("detail", {})
    bucket_name = detail.get("resourceId", "unknown")

    deny_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "QuarantineDenyAll",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                f"arn:aws:s3:::{bucket_name}",
                f"arn:aws:s3:::{bucket_name}/*"
            ]
        }]
    }

    action_taken = "no_action"
    if bucket_name != "unknown":
        s3.put_bucket_policy(Bucket=bucket_name, Policy=json.dumps(deny_policy))
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            }
        )
        action_taken = "bucket_quarantined"

    table = dynamodb.Table(os.environ["INCIDENT_TABLE_NAME"])
    table.put_item(Item={
        "incident_id": context.aws_request_id,
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "resource_arn": f"arn:aws:s3:::{bucket_name}",
        "action_taken": action_taken,
        "finding_type": detail.get("configRuleName", "unknown"),
    })

    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Subject="Incident Response: S3 bucket quarantined",
        Message=f"Bucket {bucket_name} was quarantined. Action: {action_taken}"
    )
    return {"status": "ok", "action_taken": action_taken}
