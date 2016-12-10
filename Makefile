all: package-lambda

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  package-lambda      to package the lambda function"
	@echo "  package-config      to package the NetScaler Terraform config"
	@echo "  create-lambda       to create the lambda function in AWS"
	@echo "  update-lambda       to update the lambda function in AWS"

bundle.zip: handler.py bin/terraform-provider-netscaler
	zip  bundle.zip handler.py bin/*

config.zip: config/*
	zip  config.zip config/*

package-lambda: bundle.zip
	@echo "create/update lambda deployment package (bundle.zip)"

package-config: config.zip
	@echo "create/update NetScaler Terraform files (config.zip)"

update-config: package-config
	@echo "update config in S3 bucket"
	aws s3 cp config.zip s3://${S3_TFCONFIG_BUCKET}

update-lambda:  package-lambda
	@echo "update lambda deployment package"
	aws lambda update-function-code  --function-name ConfigureNetScaler --zip-file fileb://${PWD}/bundle.zip

create-lambda:  package-lambda
	@echo "create lambda deployment package in AWS"
	setup/create_lambda.sh


create-lambda-role:
	@echo "create lambda execution role"
	setup/create_lambda_role.sh

test-local:
	@echo "Testing locally"
	python-lambda-local -l lib/ -f handler -t 50 handler.py event.json

