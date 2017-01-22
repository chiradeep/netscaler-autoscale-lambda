/* The following finds the latest 10Mbps Enterprise edition AMI*/
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
  filter {
    name = "product-code"
    values = ["9gwd6wx07zoi4fa1hrw9r2j03"]
  }
}

output "ami_id" {
  value = "${data.aws_ami.netscalervpx.id}"
}

resource "aws_autoscaling_group" "vpx-asg" {
  name                 =  "${var.name}-ns-autoscale-vpx-asg"
  max_size             = 4
  min_size             = 1
  desired_capacity     = 1
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.vpx-lc.name}"
  lifecycle {
        create_before_destroy  = true
  }
  vpc_zone_identifier = ["${var.nsip_subnet}"]

  tag {
    key                 = "Name"
    value               = "NetScalerVPX"
    propagate_at_launch = "true"
  }
  initial_lifecycle_hook {
    name                   = "ns-vpx-lifecycle-hook"
    default_result         = "CONTINUE"
    heartbeat_timeout      = 180
    lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_metadata = <<EOF
{
  "client_security_group" : "${var.client_security_group}",
  "server_security_group" : "${var.server_security_group}",
  "public_ips": "${var.public_ips}",
  "private_subnets": ["${var.server_subnets}"],
  "public_subnets": ["${var.client_subnets}"]
}
EOF
}
}

resource "aws_launch_configuration" "vpx-lc" {
  name_prefix = "${var.name}-ns-autoscale-vpx-lc-"
  image_id      = "${data.aws_ami.netscalervpx.id}"
  instance_type = "${lookup(var.allowed_sizes, var.vpx_size)}"

  #user_data       = "${file("${path.module}/userdata.sh")}"
  key_name        = "${var.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.CitrixNodesProfile.id}"
  security_groups = ["${var.security_group_id}"]

}

