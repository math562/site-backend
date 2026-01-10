import json
import os
from decimal import Decimal

import boto3

db = boto3.resource("dynamodb")

# environment variable for table name
TABLE_NAME = os.environ["TABLE_NAME"]
table = db.Table(TABLE_NAME)


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)


def lambda_handler(event, context):
    try:
        response = table.update_item(
            Key={"id": "main"},
            UpdateExpression="SET #v = if_not_exists(#v, :start) + :inc",
            ExpressionAttributeNames={"#v": "views"},
            ExpressionAttributeValues={":inc": 1, ":start": 0},
            ReturnValues="UPDATED_NEW",
        )

        views = response["Attributes"]["views"]

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://dkong.io",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
            },
            "body": json.dumps({"count": views}, cls=DecimalEncoder),
        }
    except Exception as e:
        print(e)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
