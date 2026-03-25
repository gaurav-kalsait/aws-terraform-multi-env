variable "project_name" {
  description = "gk-web"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  # WHY /16? It gives us 65,536 IPs — way more than we need,
  # but it's the AWS default and gives room to add subnets later.
  # In production, you'd plan this carefully to avoid overlap
  # if you ever connect VPCs via peering or Transit Gateway.
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  # WHY /24? Each subnet gets 256 IPs (251 usable — AWS reserves 5).
  # For public subnets that only hold ALBs, this is plenty.
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  # WHY 10.0.10.x instead of 10.0.3.x?
  # We leave a gap (10.0.3-9) for future subnets. This is a
  # real-world best practice — plan your IP space with room to grow.
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to use (must match number of subnets)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  # WHY exactly 2?
  # - 1 AZ = no redundancy (single point of failure)
  # - 2 AZs = good balance of availability vs cost
  # - 3 AZs = production-grade, but costs more (3 NAT GWs)
  # For this project, 2 AZs demonstrates the concept without
  # tripling your NAT Gateway costs ($32/month each).
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
  # WHY a toggle?
  # NAT Gateways cost ~$32/month + data transfer charges.
  # In dev, you might want to disable this to save money
  # and only enable it in staging/prod.
}

variable "single_nat_gateway" {
  description = "Use a single NAT GW instead of one per AZ (saves cost)"
  type        = bool
  default     = true
  # WHY single?
  # One NAT GW per AZ = high availability but costs 2x or 3x.
  # For dev/staging, a single NAT GW is fine.
  # For prod, set this to false for per-AZ redundancy.
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
