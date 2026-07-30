import json
import os
import urllib.request
import boto3

secrets_client = boto3.client("secretsmanager")

_cached_webhook_url = None


def _get_webhook_url():
    global _cached_webhook_url
    if _cached_webhook_url is None:
        response = secrets_client.get_secret_value(
            SecretId=os.environ["SLACK_WEBHOOK_SECRET_ARN"]
        )
        secret = json.loads(response["SecretString"])
        _cached_webhook_url = secret["webhook_url"]
    return _cached_webhook_url


def lambda_handler(event, context):
    webhook_url = _get_webhook_url()

    for record in event.get("Records", []):
        sns_message = record.get("Sns", {})
        subject = sns_message.get("Subject", "Incident Response Alert")
        message = sns_message.get("Message", "")

        slack_payload = {
            "text": f"*{subject}*\n{message}"
        }

        request = urllib.request.Request(
            webhook_url,
            data=json.dumps(slack_payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        urllib.request.urlopen(request)

    return {"status": "ok"}
