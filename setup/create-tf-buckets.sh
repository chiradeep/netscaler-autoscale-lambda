#!/bin/bash
aws s3 mb s3://$S3_TFSTATE_BUCKET
aws s3 mb s3://$S3_TFCONFIG_BUCKET

aws s3api put-bucket-versioning --bucket  $S3_TFSTATE_BUCKET --versioning-configuration Status=Enabled


