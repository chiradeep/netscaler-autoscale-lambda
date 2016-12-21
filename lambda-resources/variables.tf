variable "s3_config_bucket_name"{
    type = "string"
    default = "test-netscaler.autoscale-config.bucket"
    "description" = "The name of the S3 bucket that stores the terraform config applied to the NetScaler(s)"
}

variable "s3_state_bucket_name"{
    type = "string"
    default = "test-netscaler.autoscale-state.bucket"
    "description" = "The name of the S3 bucket that stores the terraform state file(s) associated with the NetScaler(s)"
}

variable "netscaler_vpc_subnets_ids" {
    type = "list"
    "description" = "List of subnet ids, e.g., subnet-1abcdef,subnet-2defaae that host the management NIC(s) of the NetScalers"
}

variable "netscaler_vpc_id" {
    type = "string"
    "description" = "VPC Id of the NetScaler subnets"
}

variable "netscaler_security_group_id" {
    type = "string"
    "description" = "Security group id of the NetScaler Management interface ENI"
}

variable "autoscaling_group_backend_name" {
    type = "string"
    "description" = "Name of autoscaling group  that the NetScaler(s) are load balancing to"
}
