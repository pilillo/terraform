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

resource "aws_s3_bucket" "datalake" {
    bucket = var.datalake["bucket"]
    acl = "private"
    force_destroy = true
}

resource "aws_athena_database" "datalake" {
  name   = var.datalake["db"]
  bucket = aws_s3_bucket.datalake.bucket
  depends_on = [aws_s3_bucket.datalake]
}