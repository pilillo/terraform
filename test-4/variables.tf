variable "aws" {
  
  default = {
    "profile" = "default"
    "region" = "eu-west-1"
  }
}

variable "tfstate" {
  
  default = {
    "bucket" = "pilillo-tf-state"
    "path" = "global/terraform.tfstate"
  }
}

variable "environment" {
  default = "dev"
}

variable "datalake" {
  
  default = {
    "bucket" = "pilillo-datalake"
    "db" = "myfirstdb"
  }
}

variable "input_stream" {
  
  default = {
    "name" = "terraform-kinesis-test"
    # number of shards in the stream
    "shard_count" = 1
    # retention hours - expected to be in the range (24 - 8760)
    "retention_period" = 24
  }
}