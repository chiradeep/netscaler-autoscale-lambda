module "vpx" {
  source = "./vpx"

  name = "${var.base_name}"
  vpx_size = "m3.large"
  security_group_id = "${module.vpc.default_security_group_id}"
  server_security_group = "${module.vpc.default_security_group_id}"
  client_security_group = "${module.vpc.default_security_group_id}"
  client_subnets = "${module.vpc.public_subnets[0]}"
  server_subnets = "${module.vpc.private_subnets[0]}"
  nsip_subnet = "${module.vpc.private_subnets[0]}"
  vpc_id = "${module.vpc.vpc_id}"
  key_name = "${var.key_name}"
  public_ips = "${join(",", aws_eip.public_lb_ip.*.public_ip)}"
  config_function_name = "${module.lambda.lambda_name}"
}
