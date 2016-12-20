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

