variable "aws" {
  default = {
    //"profile" = "default"
    "region" = "eu-west-1"
  }
}


variable "lambda" {

  default = {
    //"role" = ""
    "handler" = "lambda.handler"
    "runtime" = "python3.6"
    "filename" = "lambda.zip"
    "function_name" = "myfirstlambda"
  }
}