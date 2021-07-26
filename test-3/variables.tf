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