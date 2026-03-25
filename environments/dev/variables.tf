variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "gk-web"   # ← Change to YOUR project name
}