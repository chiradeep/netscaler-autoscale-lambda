module "dns" {
   source = "./dns"
   dns_enabled = false
   zone_id = "Z1PC0CAHCW564V"
   name = "cloudnativevpx"
   a_records = ["${aws_eip.public_lb_ip.*.public_ip}"]
}

