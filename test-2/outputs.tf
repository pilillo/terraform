output "region" {
  description = "AWS region."
  value       = var.aws["region"]
}

output "state_arn" {
  description = "AWS state bucket arn"
  value = aws_s3_bucket.terraform_state.arn
}