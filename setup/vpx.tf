module "vpx" {
  source = "./vpx"

  name = "${var.base_name}"
  vpx_size = "m3.large"
  security_group_id = "${module.vpc.default_security_group_id}"
  client_subnet = "${module.vpc.public_subnets[0]}"
  server_subnet = "${module.vpc.private_subnets[0]}"
  nsip_subnet = "${module.vpc.private_subnets[0]}"
  vpc_id = "${module.vpc.vpc_id}"
  eip_publicip = "${aws_eip.public_lb_ip.id}"
  key_name = "${var.key_name}"
}
