variable "aws_region" { default = "us-east-1" }
variable "key_name"{}
variable "base_name"{
  description = "Used to derive names of AWS resources. Use this to distinguish different enviroments for example"
}
