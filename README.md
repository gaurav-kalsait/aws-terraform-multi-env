# AWS Terraform Multi-Environment Infrastructure

Production-grade AWS infrastructure managed entirely through Terraform, featuring reusable modules, remote state management, and isolated environments for dev, staging, and production.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Terraform Remote State                      │
│                  S3 Bucket + DynamoDB Lock Table                │
└──────────────────────────┬──────────────────────────────────────┘
                           │ provisions
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌──────────────┐ ┌──────────┐ ┌──────────────┐
     │     DEV      │ │ STAGING  │ │    PROD      │
     │  t3.micro    │ │ t3.small │ │  t3.medium   │
     │  No NAT GW   │ │ 1 NAT GW │ │  Multi-AZ    │
     │  Single AZ   │ │ 2 AZ     │ │  2+ NAT GWs  │
     └──────────────┘ └──────────┘ └──────────────┘
```

Each environment deploys an identical architecture with different sizing:

```
                  ┌── Internet ──┐
                         │
                  ┌──────▼──────┐
                  │ Internet GW │
                  └──────┬──────┘
                         │
         ┌───────────────┼──────────────────── ┐
         │           VPC (10.x.0.0/16)         │
         │                                     │
         │  ┌─────────────┐  ┌─────────────┐   │
         │  │ Public Sub A│  │Public Sub B │   │
         │  │ 10.x.1.0/24 │  │ 10.x.2.0/24 │   │
         │  │  ALB        │  │  ALB        │   │
         │  └──────┬──────┘  └──────┬──────┘   │
         │         │                │          │
         │  ┌──────▼──────┐  ┌──────▼──────┐   │
         │  │Private Sub A│  │Private Sub B│   │
         │  │ 10.x.10.0/24│  │10.x.11.0/24 │   │
         │  │ EC2 / ASG   │  │ EC2 / ASG   │   │
         │  └──────┬──────┘  └──────┬──────┘   │
         │         │                │          │
         │  ┌──────▼──────┐  ┌──────▼──────┐   │
         │  │  DB Sub A   │  │  DB Sub B   │   │
         │  │ 10.x.20.0/24│  │10.x.21.0/24 │   │
         │  │ RDS Primary │  │ RDS Standby │   │
         │  └─────────────┘  └─────────────┘   │
         └─────────────────────────────────────┘
```

## What This Project Demonstrates

| Skill Area | Implementation |
|---|---|
| **Infrastructure as Code** | All resources defined in Terraform — zero manual console clicks |
| **Modular Design** | Reusable networking, compute, and database modules |
| **Multi-Environment Strategy** | Dev / Staging / Prod with isolated VPCs and separate state files |
| **Remote State Management** | S3 backend with DynamoDB locking to prevent concurrent applies |
| **Network Architecture** | Three-tier VPC: public, private, and database subnets across 2 AZs |
| **Security Best Practices** | Subnet isolation via route tables, encrypted state, VPC Flow Logs |
| **Cost Optimization** | NAT Gateway toggling, right-sized instances per environment |
| **CI/CD Integration** | GitHub Actions: `terraform plan` on PRs, `terraform apply` on merge |

## Project Structure

```
aws-terraform-multi-env/
│
├── bootstrap/                    # One-time setup (run first)
│   ├── main.tf                   #   S3 bucket + DynamoDB table for state
│   ├── variables.tf
│   ├── outputs.tf
│   └── example.tfvars
│
├── modules/                      # Reusable infrastructure modules
│   ├── networking/
│   │   ├── main.tf               #   VPC, subnets, IGW, NAT, route tables, flow logs
│   │   ├── variables.tf          #   Configurable inputs (CIDRs, AZs, NAT toggle)
│   │   └── outputs.tf            #   VPC ID, subnet IDs, DB subnet group
│   │
│   ├── compute/
│   │   ├── main.tf               #   ALB, ASG, launch template, security groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── database/
│       ├── main.tf               #   RDS instance, parameter group, security group
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/                 # Per-environment configurations
│   ├── dev/
│   │   ├── main.tf               #   Module calls with dev-specific variables
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── example.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── example.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── example.tfvars
│
├── .github/
│   └── workflows/
│       └── terraform.yml         # CI/CD: plan on PR, apply on merge
│
├── docs/
│   ├── architecture.png          # Architecture diagram
│   ├── cost-analysis.md          # Cost breakdown per environment
│   └── runbook.md                # Operational procedures
│
├── .gitignore
└── README.md                     # ← You are here
```

## Prerequisites

- **AWS Account** with Free Tier (or a budget of ~$30–80/month)
- **Terraform** >= 1.5.0 ([Install guide](https://developer.hashicorp.com/terraform/install))
- **AWS CLI** configured with credentials ([Setup guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html))
- **Git** and a GitHub account

### Verify your setup

```bash
terraform --version    # Should show >= 1.5.0
aws sts get-caller-identity   # Should show your AWS account ID
git --version          # Should show git version
```

## Quick Start

### Step 1: Clone the repo

```bash
git clone https://github.com/YOUR-USERNAME/aws-terraform-multi-env.git
cd aws-terraform-multi-env
```

### Step 2: Bootstrap remote state (one-time only)

This creates the S3 bucket and DynamoDB table that Terraform uses to store state.

```bash
cd bootstrap

# Create your tfvars (edit with your unique bucket name)
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars:
#   state_bucket_name = "your-unique-name-terraform-state-2026"

terraform init
terraform plan
terraform apply    # Type "yes"

# Save the output values — you'll need them next
cd ..
```

### Step 3: Deploy the dev environment

```bash
cd environments/dev

# Edit main.tf → replace "YOUR-BUCKET-NAME-HERE" with your actual bucket name

terraform init
terraform plan     # Review: ~15 resources for networking
terraform apply    # Type "yes" — takes about 60 seconds

# Check your outputs
terraform output
```

### Step 4: Verify in AWS Console

| Check | Where to look |
|---|---|
| VPC created | VPC Dashboard → Your VPCs → `myapp-dev-vpc` |
| 6 subnets | VPC Dashboard → Subnets → 2 public, 2 private, 2 database |
| Route tables correct | VPC → Route Tables → public has IGW route, database has none |
| Flow Logs active | CloudWatch → Log Groups → `/vpc/flow-logs/myapp-dev` |

### Step 5: Deploy staging and prod

```bash
# Staging
cd ../staging
terraform init && terraform plan && terraform apply

# Production
cd ../prod
terraform init && terraform plan && terraform apply
```

## Modules Reference

### Networking Module

Creates the complete VPC infrastructure with three-tier subnet isolation.

```hcl
module "networking" {
  source = "../../modules/networking"

  project_name  = "myapp"
  environment   = "dev"
  vpc_cidr      = "10.0.0.0/16"

  availability_zones    = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  enable_nat_gateway = false   # Disable in dev to save ~$32/month
  single_nat_gateway = true
}
```

| Input | Type | Description |
|---|---|---|
| `project_name` | `string` | Name prefix for all resources |
| `environment` | `string` | Environment name (dev/staging/prod) |
| `vpc_cidr` | `string` | VPC CIDR block (default: `10.0.0.0/16`) |
| `availability_zones` | `list(string)` | AZs to deploy into |
| `public_subnet_cidrs` | `list(string)` | CIDRs for public subnets |
| `private_subnet_cidrs` | `list(string)` | CIDRs for private subnets |
| `database_subnet_cidrs` | `list(string)` | CIDRs for database subnets |
| `enable_nat_gateway` | `bool` | Toggle NAT Gateway (default: `true`) |
| `single_nat_gateway` | `bool` | One NAT GW vs one per AZ (default: `true`) |

| Output | Description |
|---|---|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `database_subnet_ids` | List of database subnet IDs |
| `db_subnet_group_name` | RDS subnet group name |
| `nat_gateway_ips` | Public IPs of NAT Gateways |

### Compute Module

Deploys an Application Load Balancer, Auto Scaling Group, and EC2 instances.

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name      = "myapp"
  environment       = "dev"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  instance_type     = "t3.micro"     # Free tier eligible
  min_size          = 1
  max_size          = 2
  desired_capacity  = 1
}
```

### Database Module

Provisions an RDS instance within the isolated database subnets.

```hcl
module "database" {
  source = "../../modules/database"

  project_name       = "myapp"
  environment        = "dev"
  vpc_id             = module.networking.vpc_id
  db_subnet_group    = module.networking.db_subnet_group_name
  app_security_group = module.compute.app_security_group_id

  instance_class     = "db.t3.micro"
  engine             = "mysql"
  engine_version     = "8.0"
  allocated_storage  = 20
  multi_az           = false          # true in prod
}
```

## Environment Comparison

| Configuration | Dev | Staging | Prod |
|---|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| Instance type | `t3.micro` | `t3.small` | `t3.medium` |
| ASG min/max | 1 / 2 | 2 / 4 | 2 / 6 |
| RDS instance | `db.t3.micro` | `db.t3.small` | `db.t3.medium` |
| Multi-AZ RDS | No | No | Yes |
| NAT Gateway | Disabled | 1 (single) | 2 (per-AZ) |
| Estimated cost | ~$1/mo | ~$50/mo | ~$120/mo |

## CI/CD Pipeline

The GitHub Actions workflow automates Terraform operations:

```
Pull Request opened → terraform fmt check → terraform plan → Comment plan on PR
PR merged to main   → terraform apply (auto-approve per environment)
```

### Workflow triggers

| Event | Action |
|---|---|
| PR to `main` | Runs `terraform plan` for changed environments and posts output as PR comment |
| Push to `main` | Runs `terraform apply` for changed environments |
| Manual dispatch | Apply specific environment via workflow_dispatch |

## Cost Management

### Keeping costs near zero

- **Disable NAT Gateway in dev** (`enable_nat_gateway = false`) — saves ~$32/month
- **Use `t3.micro` instances** — Free Tier eligible for first 12 months
- **Set billing alerts** at $5, $10, $25 via CloudWatch
- **Destroy when not in use**: `terraform destroy` tears everything down cleanly
- **Use `terraform plan`** before every apply to catch unexpected cost additions

### Estimated monthly costs

| Resource | Dev | Staging | Prod |
|---|---|---|---|
| VPC + Subnets | Free | Free | Free |
| Internet Gateway | Free | Free | Free |
| NAT Gateway | $0 (disabled) | ~$32 | ~$64 (×2) |
| EC2 (ASG) | ~$0 (free tier) | ~$15 | ~$30 |
| RDS | ~$0 (free tier) | ~$25 | ~$50 |
| ALB | ~$16 | ~$16 | ~$16 |
| Flow Logs | ~$0.50 | ~$0.50 | ~$1 |
| **Total** | **~$1** | **~$50** | **~$120** |

## Security Features

- **Subnet isolation**: Database subnets have no internet route — enforced at the network layer, not just by security groups
- **Encrypted state**: S3 backend uses AES-256 server-side encryption
- **State locking**: DynamoDB prevents concurrent Terraform runs that could corrupt state
- **No hardcoded secrets**: All sensitive values passed via `terraform.tfvars` (gitignored) or AWS SSM Parameter Store
- **VPC Flow Logs**: All network traffic metadata captured in CloudWatch for audit and troubleshooting
- **Public access blocked**: S3 state bucket has all public access blocked
- **Least privilege IAM**: Flow log role has only the permissions it needs

## Troubleshooting

### `terraform init` fails with S3 access denied

```bash
# Check your AWS identity
aws sts get-caller-identity

# Verify the bucket exists and you own it
aws s3 ls s3://your-bucket-name

# Check your credentials are for the correct account
aws configure list
```

### `terraform plan` shows 0 resources

Make sure you're in the correct directory:

```bash
# You should be here:
pwd
# → .../aws-terraform-multi-env/environments/dev

# NOT here:
# → .../aws-terraform-multi-env/
```

### State lock error

Someone (or a previous run) left the state locked:

```bash
# Check who holds the lock
aws dynamodb scan --table-name terraform-state-locks

# Force unlock (use with caution!)
terraform force-unlock LOCK-ID-HERE
```

### Destroying and recreating

```bash
# Destroy everything in an environment
cd environments/dev
terraform destroy   # Type "yes"

# Recreate from scratch
terraform apply     # Type "yes"
```

## Key Design Decisions

### Why separate state files per environment?

A single state file for all environments means a mistake in dev could corrupt prod state. Separate state files (`dev/terraform.tfstate`, `staging/terraform.tfstate`, `prod/terraform.tfstate`) provide blast radius isolation — a bad apply in dev can never affect prod.

### Why modules instead of copy-paste?

Without modules, a VPC change requires editing three files (one per environment) and hoping you make the same change in each. With modules, you edit the module once and all environments inherit the fix on next apply. This also prevents configuration drift between environments.

### Why VPC Flow Logs?

Most candidates skip observability in their infrastructure projects. Flow logs let you answer questions like "why can't my app server reach the database?" by inspecting actual traffic records. In an interview, mentioning flow logs signals that you think about operations, not just provisioning.

### Why disable NAT Gateway in dev?

NAT Gateways cost ~$32/month regardless of usage. In dev, your app servers rarely need outbound internet. Disabling NAT in dev and enabling it in staging/prod shows cost-awareness — a quality interviewers actively look for in senior engineers.

## Lessons Learned

1. **Always run `terraform plan` before `terraform apply`** — I caught a misconfigured CIDR that would have overlapped with an existing VPC
2. **Remote state is non-negotiable** — Local state files get lost, can't be shared, and have no locking
3. **Name everything consistently** — The `${project}-${env}-${resource}` pattern makes resources findable in the AWS Console
4. **Test destructively** — Running `terraform destroy` and `terraform apply` proves your infrastructure is truly reproducible

## What's Next

This networking foundation supports the remaining projects in the portfolio:

- **[Project 3: CI/CD Pipeline](../aws-cicd-containerized-app)** — Deploy containers into this VPC
- **[Project 4: EKS Microservices](../aws-eks-microservices)** — Run Kubernetes in these subnets
- **[Project 6: Monitoring](../aws-monitoring-observability)** — Observe this infrastructure with Prometheus + Grafana
- **[Project 7: Security Hardening](../aws-security-hardening)** — Harden the instances running here

## License

MIT

## Author

**[Your Name]** — aspiring Senior Systems Engineer building production-grade infrastructure.

- LinkedIn: [your-linkedin]
- GitHub: [your-github]
