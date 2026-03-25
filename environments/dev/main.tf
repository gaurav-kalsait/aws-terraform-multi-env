terraform {
  required_version = ">= 1.5.0"

  # REMOTE STATE — this is why we did the bootstrap in Phase 1!
  backend "s3" {
    bucket         = "gaurav-terraform-state-1"   # ← Replace with your actual bucket
    key            = "dev/terraform.tfstate"     # ← Each env gets its own state file
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }

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

# --- USE THE NETWORKING MODULE ---
# WHY this syntax?
# source = "../../modules/networking" tells Terraform where the module code lives.
# Everything else is just passing variables.
# 
# INTERVIEW INSIGHT: When the interviewer asks "how did you handle
# different environments?", your answer is: "Same module, different
# variables. Dev gets smaller subnets and a single NAT GW. 
# Prod gets multi-AZ NAT GWs."

module "networking" {
  source = "../../modules/networking"

  project_name  = var.project_name
  environment   = "dev"
  vpc_cidr      = "10.0.0.0/16"
  
  availability_zones    = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  # DEV COST SAVINGS:
  enable_nat_gateway = false   # ← Save ~$32/month! Dev doesn't need outbound internet
  single_nat_gateway = true

  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}