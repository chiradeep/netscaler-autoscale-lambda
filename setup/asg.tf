module "asg" {
  source = "./asg"

  name = "qa"
  asg_security_group = "${module.vpc.default_security_group_id}"
  vpc_subnets = "${module.vpc.private_subnets}"
  key_name = "${var.key_name}"
}
