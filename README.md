# Automate NetScaler configuration in AWS using AWS Lambda
Provides a [AWS Lambda](https://aws.amazon.com/lambda) function to manage the configuration of [Citrix NetScaler VPX instances in AWS](https://aws.amazon.com/marketplace/seller-profile?id=fb9c6078-b60f-47f6-8622-49d5e1d5aca7). The idea is to automate the reconfiguration of the NetScaler VPX when it load balances to a set of backend instances in an [AutoScaling Group (ASG)](https://aws.amazon.com/autoscaling/). As the ASG shrinks and expands, the lambda function reconfigures the NetScaler VPX appropriately.


# Theory of operation
The lambda function is bundled with a natively compiled [Terraform](https://terraform.io/) [provider](https://github.com/citrix/terraform-provider-netscaler) that can configure Citrix NetScaler using [the Nitro API](https://docs.citrix.com/en-us/netscaler/11/nitro-api.html). AWS Lambda functions can execute [natively compiled executables](https://aws.amazon.com/blogs/compute/running-executables-in-aws-lambda/). The lamdba function is configured to react to two sources of events:

* an S3 bucket that holds the terraform config file that configures the NetScaler
* Autoscaling events for the target ASG

When these events happen, the lambda function is invoked. The lambda function downloads the config file from the S3 bucket, the previous [tfstate](https://www.terraform.io/docs/state/) file from another S3 bucket and [applies](https://www.terraform.io/docs/commands/apply.html) the configuration to the NetScaler VPX. To discover the set of VPXs that it needs to configure, the lambda function searches for a particular instance tag. After successfully configuring the VPX(s), the lambda function uploads the new tfstate file to S3. Since multiple events (especially autoscale events) could happen very near each other, we have to protect from concurrent executions of the lambda instance. We use a [mutex implemented using DynamoDB](https://github.com/chiradeep/lambda-mutex)  to protect the critical section that configures the NetScaler.

<img src="docs/figure.png" width="720"/>


# Pre-requisites

* VPC with VPC endpoint to S3
* VPC must have NAT gateway and at least 1 private subnet. Ideally the NetScaler VPX will have its own private management subnet for [NSIP address] (https://docs.citrix.com/en-us/netscaler/11/networking/ip-addressing/configuring-netscaler-owned-ip-addresses/configuring-netscaler-ip-address.html)
* An Autoscaling group in the VPC (that the VPX will loadbalance to)
* [Terraform](https://terraform.io) on your local machine to automate the deployment of the lambda function.

<img src="docs/NS - single VPX AWS deployment.png" width="720"/>

You can deploy the VPX

# Usage

## Creating the lambda function from scratch
You can deploy a sandbox VPC, VPX and autoscaling group to see the lambda function work. 
Use the Terraform config in [./setup](./setup). Or, use the Makefile

```
make  create-lambda-full

OR
cd setup; terraform get; terraform apply
```

The full terraform config expects a few  inputs such as AWS region, the name of a keypair in that region and a base name that can be prefixed to all the resources.  This can be suppliedon the command line, or interactively:

```
cd setup; terraform apply 

OR
cd setup; terraform apply -var 'key_name=mykeypair_us_west_2' -var 'aws_region=us-west-2' -var 'base_name=qa-staging'

```
The VPC that is created is similar to the figure above: the difference is that only two subnets are created. (The management subnet and the server subnet are merged)

In addition to events from the autoscaling group and the config bucket, a scheduled event will invoke the lambda function every 15 minutes.


## Creating the lambda to attach to an existing VPC, VPX and ASG
The lambda terraform config expects a number of inputs such as the VPC configuration, the tag on the NetScaler VPX instance, etc. This can be suppliedon the command line, or in the [terraform.tfvars](./setup/lambda/terraform.tfvars) file. The set of inputs is documented in [variables.tf](./setup/lambda/variables.tf).
An example of using the command line:

```
cd setup/lambda
terraform apply -var 'autoscaling_group_backend_name=webservers-us-west-2a' -var 'netscaler_vpc_id=vpc-094ebf6e' -var 'netscaler_vpc_nsip_subnet_ids=["subnet-24e20d61"]' -var 'netscaler_vpc_client_subnet_ids=["subnet-853f09e3"]' -var 'netscaler_security_group_id=sg-c36b19ba'
```


## Configuration of the NetScaler VPX
The Terraform config that configures the NetScaler should be in the [./config](./config) subdirectory. An example is provided. To make changes and upload the config, use

```
make update-config
```

Make sure the config bucket matches the `S3_TFCONFIG_BUCKET` enviroment variable.

```
export S3_TFCONFIG_BUCKET=$(terraform output -module lambda config_bucket)

```

This should upload a `config.zip` file to the S3 config bucket, which should then trigger the lambda function. Of note is the variable `vip_config` - if the terraform config has this map variable, then the key `vip` in the map will be set to the IP of the client ENI of the NetScaler.

# See it work
If everything works, then the IP of the public interface of the VPX can be retrieved:

```
vip=$(terraform output -module vpx vpx_public_ip)
```

You can see the VPX at work:

```
wget http://$vip/
```

# Workflow
Once the lambda function is created and the initial terraform config has been uploaded, the DevOps team can make changes to the config using `make update-config`. An alternative is to have a separate git repository for the config and use Git webhooks to update `config.zip` in the S3 bucket. Github webhooks can be [automated using](https://aws.amazon.com/blogs/compute/dynamic-github-actions-with-aws-lambda/) AWS lambda as well.

# Troubleshooting
Use CloudWatch logs to troubleshoot. The output of `terraform apply` is buried between the mutex acquire and release logs.

# Development notes
Use `make update-lambda` to update the lambda function when you change the code in `handler.py`. Use `make invoke-lambda` to test the function independent of any events. (Note: Depending on the region that the terraform config was applied, you might have to change the default region for your AWS CLI to use this effectively).
Testing locally using `make test-local` is a little bit involved. You have to set up the environment variables expected by the lambda function, and then fake the actual execution of the terraform apply (replace bin/terraform with a simple shell script)


# Resources used
The monetary cost should be zero or close to it.

* A DynamoDB table to hold the mutex (low throughput: 2 writes/sec)
* Lambda execution. The number of executions is controlled by the number of scaling events and the number of config changes. Generally this should be in the free tier.
* S3 usage to hold the tfstate file and config file. This should be in the single-digit KB range.
* IAM permissions

# Cleanup
Use `terraform destroy` to destroy the resources created by `make create-lambda`. 

# TODO

* Add SNS notifications on failure
* Create custom cloudwatch metrics such as number of mutex acquisition failures.

# Limitations
* Only 1 IP per NetScaler client ENI is supported. If you have secondary IPs for the Client ENI then you have to change `handler.py` and your terraform config appropriately (see `find_ns_vpx_instances()`). For example you can modify the code to read in the IP from an environment variable instead of auto-discovering it from the client ENI's primary IP.
