variable "aws_region" {
  description = "AWS region for state resources"
  type        = string
  default     = "ap-south-1"  # Change to your preferred region
}

variable "state_bucket_name" {
  description = "gaurav-terraform-state-1"
  type        = string
  # ⚠️  IMPORTANT: Change this! S3 bucket names are global across ALL AWS accounts.
  # Use something like: "your-name-terraform-state-2026"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-locks"
}