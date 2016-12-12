#!/bin/bash
lambda_arn=$(aws iam list-roles  | jq -r '.Roles[] | select(.RoleName == "lambda-vpc-execution") | .Arn')
echo "Lambda ARN is $lambda_arn"

LAMBDA_SUBNET_IDS=subnet-953f09e3
LAMBDA_SECURITY_GROUP_IDS=sg-3c383945
LAMBDA_FUNCTION_NAME=ConfigureNetScalerAutoScale
TIMEOUT=90

aws lambda create-function --function-name   $LAMBDA_FUNCTION_NAME  --zip-file fileb://${PWD}/bundle.zip --role $lambda_arn --handler handler.handler --runtime python2.7 --vpc-config SubnetIds=$LAMBDA_SUBNET_IDS,SecurityGroupIds=$LAMBDA_SECURITY_GROUP_IDS  --timeout $TIMEOUT --environment '{ "Variables": { "NS_URL": "$NS_URL", "NS_LOGIN": "$NS_LOGIN", "NS_PASSWORD": "$NS_PASSWORD", "S3_TFSTATE_BUCKET": "$S3_TFSTATE_BUCKET", "S3_TFCONFIG_BUCKET":"$S3_TFCONFIG_BUCKET" } }'
