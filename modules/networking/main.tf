# --------------------
# VPC
# --------------------
# The VPC is your isolated network. Everything else lives inside it.
# enable_dns_support and enable_dns_hostnames let resources resolve
# each other by hostname instead of just IP — critical for RDS,
# which gives you a DNS endpoint like "mydb.abc123.us-east-1.rds.amazonaws.com"

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# --------------------
# INTERNET GATEWAY
# --------------------
# WHY? Without this, nothing in your VPC can talk to the internet.
# The IGW is the "front door" — it connects your VPC to the public internet.
# Only ONE IGW per VPC (AWS enforced).

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# --------------------
# PUBLIC SUBNETS
# --------------------
# WHY count?
# We use count = length(var.public_subnet_cidrs) to create one
# subnet per CIDR we defined. If we add a third AZ later, we just
# add a third CIDR to the variable — no code changes needed.
#
# WHY map_public_ip_on_launch?
# Resources launched here automatically get a public IP.
# This is what makes it a "public" subnet (along with the route table).

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# --------------------
# PRIVATE SUBNETS
# --------------------
# Same pattern as public, but NO public IP assignment.
# These subnets can only be reached from within the VPC.

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

# --------------------
# DATABASE SUBNETS
# --------------------
# WHY separate from private?
# 1. RDS requires a "DB subnet group" with subnets in 2+ AZs
# 2. Database subnets have NO route to internet (not even via NAT)
# 3. Separation makes security auditing easier — you can prove
#    databases are isolated just by looking at route tables

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}

# --------------------
# RDS SUBNET GROUP
# --------------------
# WHY? RDS won't launch without this. It tells RDS "you can place
# your primary in AZ-a and your standby in AZ-b."

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# --------------------
# ELASTIC IP FOR NAT GATEWAY
# --------------------
# WHY Elastic IP?
# NAT Gateway needs a static public IP so outbound traffic from
# your private subnets always comes from the same IP. This matters
# if you need to whitelist your IP with external services.

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

# --------------------
# NAT GATEWAY
# --------------------
# WHY?
# Private subnet instances need to download packages, pull Docker
# images, call external APIs. NAT Gateway lets them make OUTBOUND
# connections without allowing INBOUND connections from the internet.
# 
# Think of it like your home router — your laptop can browse the web,
# but nobody on the internet can connect directly to your laptop.

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

# --------------------
# ROUTE TABLES
# --------------------
# WHY route tables?
# A subnet is "public" or "private" BECAUSE of its route table.
# - Public route table: 0.0.0.0/0 → Internet Gateway (all traffic goes to internet)
# - Private route table: 0.0.0.0/0 → NAT Gateway (outbound only)
# - Database route table: NO 0.0.0.0/0 route (completely isolated)
#
# WITHOUT a route table, a subnet can only talk to other subnets
# in the same VPC. The route table is what opens the door.

# --- Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"          # "All traffic..."
    gateway_id = aws_internet_gateway.main.id  # "...goes to the Internet Gateway"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table ---
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 1
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index}"
  })
}

# Private route to NAT Gateway (only if NAT is enabled)
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# --- Database Route Table (NO internet route) ---
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  # NO routes here! Database subnets are fully isolated.
  # They can only communicate within the VPC.

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-rt"
  })
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# --------------------
# VPC FLOW LOGS (BONUS — shows security awareness)
# --------------------
# WHY? Flow logs capture all network traffic metadata (source, dest,
# port, action). Essential for troubleshooting "why can't server A
# talk to server B?" and for security audits.
# Interviewers LOVE seeing this because most candidates skip it.

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/flow-logs/${var.project_name}-${var.environment}"
  retention_in_days = 30  # Keep logs for 30 days (cost-conscious)

  tags = var.common_tags
}

# IAM role for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-${var.environment}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}
