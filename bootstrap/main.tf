# ============================================================
# BOOTSTRAP: Creates S3 bucket + DynamoDB for Terraform state
# Run this ONCE, then never touch it again.
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- S3 BUCKET FOR STATE FILES ---
# WHY S3?
# - Durable (99.999999999% — "eleven nines")
# - Versioned (if state gets corrupted, we can roll back)
# - Encrypted (state contains sensitive data like DB passwords)
# - Cheap (pennies per month for small state files)

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion — you'll thank yourself later
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State"
    Environment = "management"
    ManagedBy   = "terraform-bootstrap"
  }
}

# Enable versioning — every state change is saved
# WHY? If a bad apply corrupts state, you can restore the previous version
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — state files contain secrets
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block ALL public access — state files are sensitive
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DYNAMODB TABLE FOR STATE LOCKING ---
# WHY DynamoDB?
# Imagine you and a teammate both run "terraform apply" at the same time.
# Without locking, both could try to create the same resource → chaos.
# DynamoDB acts as a "mutex lock" — only one person can apply at a time.
# The other gets: "Error: state locked by [teammate] since [timestamp]"

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"  # Free tier friendly — you pay per lock/unlock
  hash_key     = "LockID"           # Terraform uses this key automatically

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform Lock Table"
    Environment = "management"
    ManagedBy   = "terraform-bootstrap"
  }
}