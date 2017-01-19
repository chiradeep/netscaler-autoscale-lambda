output "launch_configuration" {
  value = "${aws_launch_configuration.vpx-lc.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.vpx-asg.id}"
}
