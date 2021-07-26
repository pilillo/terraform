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


resource "aws_kinesis_stream" "input_stream" {
  name             = var.input_stream["name"]
  shard_count      = var.input_stream["shard_count"]
  retention_period = var.input_stream["retention_period"]

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  tags = {
    Environment = var.environment
  }
}


resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  depends_on = [aws_iam_role.firehose_role, aws_kinesis_stream.input_stream]
  name        = "terraform-kinesis-firehose-test-stream"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.datalake.arn
  }
}