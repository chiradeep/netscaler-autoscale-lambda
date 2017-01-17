output "vpx_id" {
  value = "${aws_instance.netscalervpx.id}"
}

output "vpx_public_ip" {
  value = "${aws_eip.client_public_ip.public_ip}"
}

output "vpx_client_ip" {
  value = "${aws_eip.client_public_ip.private_ip}"
}

output "vpx_nsip" {
  value = "${aws_network_interface.NsipENI.private_ips[0]}"
}
