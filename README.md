# Personal Website Backend

This site is serverless and uses the following tech stack:
- Amazon S3 to host the static website files
- Route 53 as the DNS provider
- CloudFront for routing & content delivery
- DynamoDB as a lightweight, no-SQL database (for the visitor counter)
- AWS API Gateway and Lambda services for communications with the database
- Terraform for configuring website and API resources

The backend is mostly contained in the files:
- main.tf (S3, DynamoDB, API Gateway, Lambda)
- cloudfront.tf (Route 53, CloudFront)
- counter.py (visitor counter API)
