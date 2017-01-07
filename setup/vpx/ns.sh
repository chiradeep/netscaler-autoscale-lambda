#!/bin/bash
set -x

aws cloudformation create-stack --stack-name vpx-stack --template-body file://./ns.template --capabilities CAPABILITY_IAM --parameters ParameterKey=VPX,ParameterValue=m3.large ParameterKey=ServerSubnet,ParameterValue=subnet-28e20d61 ParameterKey=KeyName,ParameterValue=aws_citrix_us_west_2 ParameterKey=VpcID,ParameterValue=vpc-094ebf6e ParameterKey=ClientSubnet,ParameterValue=subnet-953f09e3 ParameterKey=SecurityGroup,ParameterValue=sg-c36b19ba ParameterKey=NsipSubnet,ParameterValue=subnet-28e20d61
