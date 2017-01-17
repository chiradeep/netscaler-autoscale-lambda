data "aws_ami" "netscalervpx" {
  most_recent = true
  filter {
    name = "name"
    values = ["Citrix NetScaler and CloudBridge Connector*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

output "ami_id" {
  value = "${data.aws_ami.netscalervpx.id}"
}
resource "aws_security_group" "client_sg" {
    name = "client_sg"
    ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
       from_port = 0
       to_port = 0
       protocol = "-1"
       cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${var.vpc_id}"
}

resource "aws_network_interface" "ServerENI" {
    subnet_id = "${var.server_subnet}"
    security_groups =  ["${var.security_group_id}"]
    description =  "ENI connected to server subnet"
    tags {
           Purpose = "ServerENI"
    }
    attachment {
        instance = "${aws_instance.netscalervpx.id}"
        device_index = 2
    }
}


resource "aws_network_interface" "ClientENI" {
    subnet_id = "${var.client_subnet}"
    security_groups =  ["${aws_security_group.client_sg.id}"]
    description = "ENI connected to client subnet"
    tags {
           Purpose = "ClientENI"
    }
    attachment {
        instance = "${aws_instance.netscalervpx.id}"
        device_index = 1
    }
} 

resource "aws_iam_instance_profile" "CitrixNodesProfile" {
    name_prefix = "CitrixNodesProfile"
    roles = ["${aws_iam_role.CitrixNodesInstanceRole.name}"]
}

resource "aws_iam_role" "CitrixNodesInstanceRole" {
    name_prefix = "CitrixNodesInstanceRole"
    path = "/"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "Citrixnode" {
    name = "Citrixnode"
    role = "${aws_iam_role.CitrixNodesInstanceRole.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DetachNetworkInterface",
        "ec2:AttachNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "netscalervpx" {
    ami =  "${data.aws_ami.netscalervpx.id}"
    subnet_id = "${var.nsip_subnet}"
    instance_type = "${lookup(var.allowed_sizes, var.vpx_size)}"
    vpc_security_group_ids = ["${var.security_group_id}"]
    tags { 
       Name = "NetScalerVPX"
    }
    key_name = "${var.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.CitrixNodesProfile.id}"
}

resource "aws_eip_association" "client_public_ip" {
  allocation_id = "${var.eip_publicip}"
  network_interface_id = "${aws_network_interface.ClientENI.id}"
}
