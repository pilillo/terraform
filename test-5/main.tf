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

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
resource "aws_lambda_function" "test5_lambda" {
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda["handler"]
  runtime          = var.lambda["runtime"]
  filename         = var.lambda["filename"]
  function_name    = var.lambda["function_name"]
  source_code_hash = filebase64sha256(var.lambda["filename"])
}