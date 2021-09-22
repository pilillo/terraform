terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"

  /* uncomment to use s3 state backend
    backend "s3" {
        bucket = "pilillo-tf-state"
        region = "eu-west-1"
        key="global/terraform.tfstate"
    }
    */
}

provider "aws" {
  //profile = var.aws["profile"]
  region = var.aws["region"]
  //access_key = "123"
  //secret_key = "xyz"

  skip_credentials_validation = true
  skip_requesting_account_id = true
  skip_metadata_api_check = true
  
  s3_force_path_style = true
  # use localstack as target
  endpoints {
    iam = "http://localhost:4566"
    s3 = "http://localhost:4566"
    lambda = "http://localhost:4566"
    kinesis = "http://localhost:4566"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name        = "lambda_exec"
  path        = "/"
  description = "Allows Lambda Function to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}



resource "aws_lambda_function" "test6_lambda" {
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda["handler"]
  runtime          = var.lambda["runtime"]
  filename         = var.lambda["filename"]
  function_name    = var.lambda["function_name"]
  source_code_hash = filebase64sha256(var.lambda["filename"])
}