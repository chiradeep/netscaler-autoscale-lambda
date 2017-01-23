variable "name" {}
variable "vpx_size" {}
variable "server_subnets" {}
variable "client_subnets" {}
variable "nsip_subnet" {}
variable "vpc_id" {}
variable "security_group_id" {}
variable "public_ips" {}
variable "server_security_group" {}
variable "client_security_group" {}
variable "key_name" {}
variable "config_function_name" {}
variable "allowed_sizes" {
   type = "map"
   description = "list of allowed vpx sizes"
   default = {
      m3.large = "m3.large"
      m3.xlarge = "m3.xlarge"
      m3.2xlarge = "m3.2xlarge"
      m4.large = "m4.large"
      m4.xlarge = "m4.xlarge"
      m4.2xlarge = "m4.2xlarge"
      m4.4xlarge = "m4.4xlarge"
      m4.10xlarge = "m4.10xlarge"
   }
}
