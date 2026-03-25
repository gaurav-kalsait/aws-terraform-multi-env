output "state_bucket_name" {
  description = "S3 bucket for Terraform state — use this in backend configs"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "DynamoDB table for state locking — use this in backend configs"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "state_bucket_arn" {
  description = "ARN of the state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}