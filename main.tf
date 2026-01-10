provider "aws" {
    region = "us-east-2"
}

provider "aws" {
    alias = "us_east_1"
    region = "us-east-1"
}

variable "domain_name" {
    default = "dkong.io"
}

resource "aws_dynamodb_table" "visitor_table" {
    name = "VisitorCounter"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
        name = "id"
        type = "S"
    }
}

resource "aws_iam_role" "lambda_role" {
    name = "visitor_counter_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_policy" "lambda_policy" {
    name = "visitor_counter_policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = [
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:UpdateItem"
                ]
                Effect = "Allow"
                Resource = aws_dynamodb_table.visitor_table.arn
            },
            {
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                ]
                Effect = "Allow"
                Resource = "arn:aws:logs:*:*:*"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_file = "counter.py"
    output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "visitor_counter" {
    filename = data.archive_file.lambda_zip.output_path
    function_name = "UpdateVisitorCount"
    role = aws_iam_role.lambda_role.arn
    handler = "counter.lambda_handler"
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    runtime = "python3.9"

    environment {
        variables = {
            TABLE_NAME = aws_dynamodb_table.visitor_table.name
        }
    }
}

resource "aws_apigatewayv2_api" "http_api" {
    name = "ResumeCounterAPI"
    protocol_type = "HTTP"

    cors_configuration {
        allow_origins = ["https://dkong.io", "https://www.dkong.io"]
        allow_methods = ["GET", "OPTIONS"]
        allow_headers = ["content-type"]
        max_age = 300
    }
}

resource "aws_apigatewayv2_stage" "default" {
    api_id = aws_apigatewayv2_api.http_api.id
    name = "$default"
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
    api_id = aws_apigatewayv2_api.http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_apigatewayv2_route" "get_count" {
    api_id = aws_apigatewayv2_api.http_api.id
    route_key = "GET /count"
    target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.visitor_counter.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_url" {
    value = "${aws_apigatewayv2_stage.default.invoke_url}/count"
}

resource "aws_s3_bucket" "website_bucket" {
    bucket = "dkong-site"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
    bucket = aws_s3_bucket.website_bucket.id
    index_document {
        suffix = "index.html"
    }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket = aws_s3_bucket.website_bucket.id
    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
    bucket = aws_s3_bucket.website_bucket.id
    depends_on = [aws_s3_bucket_public_access_block.public_access]

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "PublicReadGetObject"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:GetObject"
                Resource = "${aws_s3_bucket.website_bucket.arn}/*"
            },
        ]
    })
}

output "website_url" {
    value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}
