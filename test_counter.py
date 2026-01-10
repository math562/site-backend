import json
import os
import unittest

import boto3
from moto import mock_aws

# environment variables

os.environ["TABLE_NAME"] = "VisitorCounter"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"

import counter


@mock_aws
class TestVisitorCounter(unittest.TestCase):
    def setUp(self):
        self.dynamodb = boto3.resource("dynamodb", region_name="us-east-1")

        self.table = self.dynamodb.create_table(
            TableName="VisitorCounter",
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{'AttributeName': 'id', 'AttributeType': 'S'}],
            ProvisionedThroughput={"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
        )

    def test_lambda_handler_success(self):
        # First call: initiate counter to 1
        response = counter.lambda_handler({}, {})
        body = json.loads(response["body"])

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(body["count"], 1)

        # Second call: increment counter
        response = counter.lambda_handler({}, {})
        body = json.loads(response["body"])

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(body["count"], 2)

    def test_cors_headers(self):
        response = counter.lambda_handler({}, {})
        headers = response["headers"]

        self.assertIn("Access-Control-Allow-Origin", headers)
        self.assertEqual(headers["Access-Control-Allow-Origin"], "https://dkong.io")

    def test_dynamodb_error(self):
        # Delete table to induce error
        self.table.delete()

        response = counter.lambda_handler({}, {})

        self.assertEqual(response["statusCode"], 500)
        self.assertIn("error", response["body"])


if __name__ == "__main__":
    unittest.main()
