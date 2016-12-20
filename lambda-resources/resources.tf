
resource "aws_s3_bucket" "config_bucket" {
    bucket = "${var.s3_config_bucket_name}"
    acl = "private"
    tags {
        Description = "Holds terraform config that drives NetScaler configuration"
    }
}

resource "aws_s3_bucket" "state_bucket" {
    bucket = "${var.s3_state_bucket_name}"
    acl = "private"
    tags {
        Description = "Holds terraform state that reflects NetScaler configuration"
    }
}

resource "aws_iam_policy" "s3_policy" {
    name = "s3_netscaler_objects_policy"
    path = "/netscaler-auto-scale/"
    description = "Allows autoscale lambda access to config and statebuckets"
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
        }]
}
EOF
}

resource "aws_dynamodb_table" "netscaler-autoscale-mutex" {
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
            "Resource": "${aws_dynamodb_table.netscaler-autoscale-mutex.arn}"
        }
    ]
}
EOF
}
