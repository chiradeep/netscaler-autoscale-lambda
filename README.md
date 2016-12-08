# Automate NetScaler configuration in AWS using AWS Lambda


# Pre-requisites
* VPC with VPC endpoint to S3
* Lambda role must have : AmazonS3FullAccess and AWSLambdaVPCAccessExecutionRole policies
* Security group for lambda should have access to management port of NetScaler VPX
* S3 buckets for config and state files
