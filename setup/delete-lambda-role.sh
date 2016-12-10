#!/bin/bash

lambda_execution_role_name=lambda_vpc_exec_role
aws iam detach-role-policy --role-name $lambda_execution_role_name --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam detach-role-policy --role-name $lambda_execution_role_name --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
aws iam detach-role-policy --role-name $lambda_execution_role_name --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

aws iam delete-role --role-name $lambda_execution_role_name
