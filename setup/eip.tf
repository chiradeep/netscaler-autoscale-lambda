resource "aws_eip" "public_lb_ip" {
  vpc      = true
  #count = "${length(module.vpc.public_subnets)}"
}
