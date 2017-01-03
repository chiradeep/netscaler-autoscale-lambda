
resource "aws_s3_bucket" "config_bucket" {
    bucket = "${var.s3_config_bucket_name}"
    acl = "private"
    force_destroy = "true"
    versioning {
       enabled = true
    }
    tags {
        Description = "Holds terraform config that drives NetScaler configuration"
    }
}

resource "aws_s3_bucket" "state_bucket" {
    bucket = "${var.s3_state_bucket_name}"
    acl = "private"
    versioning {
       enabled = true
    }
    force_destroy = "true"
    tags {
        Description = "Holds terraform state that reflects NetScaler configuration"
    }
}

resource "aws_iam_policy" "s3_policy" {
    name = "s3_netscaler_objects_policy"
    path = "/netscaler-auto-scale/"
    description = "Allows autoscale lambda access to config and state buckets"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetObject"],
	"Resource": "arn:aws:s3:::${var.s3_config_bucket_name}/*"
        }, 
        {
         "Effect": "Allow",
         "Action": ["s3:GetObject","s3:PutObject"],
	 "Resource": "arn:aws:s3:::${var.s3_state_bucket_name}/*"
        },
        {
         "Effect": "Allow",
         "Action": ["s3:ListBucket"],
	 "Resource": "arn:aws:s3:::${var.s3_state_bucket_name}"
        },
        {
         "Effect": "Allow",
         "Action": ["s3:ListBucket"],
	 "Resource": "arn:aws:s3:::${var.s3_config_bucket_name}"
        }]
}
EOF
}

resource "aws_dynamodb_table" "netscaler_autoscale_mutex" {
    name = "NetScalerAutoScaleLambdaMutex"
    read_capacity = 2
    write_capacity = 2
    hash_key = "lockname"
    attribute {
      name = "lockname"
      type = "S"
    }
}

resource "aws_iam_policy" "dynamodb_policy" {
    name = "s3_netscaler_dynamodb_mutex__policy"
    path = "/netscaler-auto-scale/"
    description = "Allows autoscale lambda access to mutex"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1482201420000",
            "Effect": "Allow",
            "Action": [
                "dynamodb:DeleteItem",
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem"
            ],
            "Resource": "${aws_dynamodb_table.netscaler_autoscale_mutex.arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role" "role_for_netscaler_autoscale_lambda" {
    name = "role_for_netscaler_autoscale_lambda"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_security_group" "lambda_security_group" {
  description = "Security group for lambda in VPC"
  name = "netscaler_autoscale_lambda_sg"
  vpc_id = "${var.netscaler_vpc_id}"
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group_rule" "allow_lambda_access_to_netscaler" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    source_security_group_id = "${aws_security_group.lambda_security_group.id}"

    security_group_id = "${var.netscaler_security_group_id}"
}

resource "aws_lambda_function" "netscaler_autoscale_lambda" {
    filename = "../bundle.zip"
    function_name = "netscaler_autoscale_lambda"
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.arn}"
    handler = "handler.handler"
    runtime = "python2.7"
    timeout = 90
    memory_size = 128
    source_code_hash = "${base64sha256(file("../bundle.zip"))}"
    environment {
        variables = {
            NS_LOGIN = "nsroot"
            NS_VPX_TAG_KEY="${var.ns_vpx_tag_key}"
            NS_VPX_TAG_VALUE="${var.ns_vpx_tag_value}"
            NS_VPX_SUBNET_IDS="${join(",", var.netscaler_vpc_subnet_ids)}"
            S3_TFSTATE_BUCKET = "${var.s3_state_bucket_name}"
            S3_TFCONFIG_BUCKET = "${var.s3_config_bucket_name}"
            ASG_NAME = "${var.autoscaling_group_backend_name}"
        }
    }
    vpc_config {
        subnet_ids = "${var.netscaler_vpc_subnet_ids}"
        security_group_ids = ["${aws_security_group.lambda_security_group.id}"]
    }
}

resource "aws_cloudwatch_event_target" "asg_autoscale_trigger_netscaler_lambda" {
  rule = "${aws_cloudwatch_event_rule.asg_autoscale_events.name}"
  arn = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
}

resource "aws_cloudwatch_event_rule" "asg_autoscale_events" {
  name = "asg_autoscale_events"
  description = "Capture all EC2 scaling events"
  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Launch Successful",
    "EC2 Instance Terminate Successful"
  ],
  "detail": {
     "AutoScalingGroupName": [
      "${var.autoscaling_group_backend_name}"
     ]
  }
}
PATTERN
}

resource "aws_lambda_permission" "s3_config_bucket_to_lambda" {
    statement_id = "AllowExecutionFromS3Bucket"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
    principal = "s3.amazonaws.com"
    source_arn = "${aws_s3_bucket.config_bucket.arn}"
}

resource "aws_lambda_permission" "cloudwatch_event_to_lambda" {
    statement_id = "AllowExecutionFromCloudWatchEvent"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.asg_autoscale_events.arn}"
}


resource "aws_s3_bucket_notification" "bucket_notification" {
    bucket = "${aws_s3_bucket.config_bucket.id}"
    lambda_function {
        lambda_function_arn = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
        events = ["s3:ObjectCreated:*"]
    }
}


resource "aws_iam_role_policy_attachment" "lambda_role_auth_dyndb" {
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
    policy_arn = "${aws_iam_policy.dynamodb_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_role_auth_s3" {
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
    policy_arn = "${aws_iam_policy.s3_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_role_auth_ec2" {
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_role_auth_vpc" {
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_role_auth_exec_lambda" {
    role = "${aws_iam_role.role_for_netscaler_autoscale_lambda.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}
