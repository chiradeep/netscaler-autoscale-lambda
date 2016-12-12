RULE_NAME=ASG_${ASG_NAME}_NS_RULE
LAMBDA_FUNCTION_NAME=ConfigureNetScalerAutoScale

LAMBDA_ARN=$(aws lambda list-functions | jq -r '.Functions[]|select(.FunctionName == "$LAMBDA_FUNCTION_NAME") | .FunctionArn')

aws events put-rule --name $RULE_NAME --event-pattern "{\"source\":[\"aws.autoscaling\"],\"detail-type\":[\"EC2 Instance Launch Successful\",\"EC2 Instance Terminate Successful\"],\"detail\":{\"AutoScalingGroupName\":[\"$ASG_NAME\"]}}"
aws events put-targets --rule $RULE_NAME --targets Arn=$LAMBDA_ARN,Id=1
