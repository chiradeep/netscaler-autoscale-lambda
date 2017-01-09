resource "aws_vpc_endpoint" "private-s3" {
    vpc_id = "${module.vpc.vpc_id}"
    service_name = "com.amazonaws.us-west-2.s3"
    route_table_ids = ["${module.vpc.private_route_table_ids[0]}"]
    policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}
