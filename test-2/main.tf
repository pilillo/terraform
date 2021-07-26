terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.27"
        }
    }
    required_version = ">= 0.14.9"

    backend "s3" {
        bucket = "pilillo-tf-state"
        region = "eu-west-1"
        key="global/terraform.tfstate"
    }

}

provider "aws" {
    profile = var.aws["profile"]
    region = var.aws["region"]
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.tfstate["bucket"]
  
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}