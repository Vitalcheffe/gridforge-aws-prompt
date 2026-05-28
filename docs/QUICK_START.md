# GridForge — Quick Start Guide

> Get from zero to a fully validated smart grid infrastructure in under 30 minutes

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| AWS CLI | >= 2.13 | `pip install awscli` or [download](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | >= 1.5.0 | [download](https://developer.hashicorp.com/terraform/downloads) |
| Python | >= 3.9 | [download](https://www.python.org/downloads/) |
| Git | >= 2.30 | [download](https://git-scm.com/downloads) |
| AWS Account | Active | [signup](https://aws.amazon.com/) |

### AWS Account Setup

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/)
2. Ensure you have access to the **af-south-1** (Cape Town) region
3. Create an IAM user with programmatic access and these permissions:
   - `AmazonIoTFullAccess`
   - `AmazonKinesisFullAccess`
   - `AmazonTimestreamFullAccess`
   - `AmazonS3FullAccess`
   - `AWSLambda_FullAccess`
   - `AmazonBedrockFullAccess`
   - `AWSCloudFormationFullAccess`
   - `AmazonVPCFullAccess`

```bash
# Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, default region: af-south-1
```

---

## Option A: Use the Prompt Only (5 minutes)

This is the core of the hackathon submission — **the prompt itself generates everything**.

1. Open [`GridForge_PROMPT.txt`](../GridForge_PROMPT.txt)
2. Copy the entire contents
3. Paste into any LLM:
   - [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
   - [Claude](https://claude.ai/)
   - [ChatGPT](https://chat.openai.com/)
4. Provide your grid parameters as input:

```
Deploy grid monitoring for Volta River Authority in Ghana with 8,000 meters
```

5. The LLM will generate:
   - Architecture overview with Mermaid diagram
   - Complete Terraform IaC (8 modules)
   - Security controls (NERC CIP mapped)
   - Cost estimate for af-south-1
   - Deployment guide
   - Validation commands

---

## Option B: Clone and Deploy (15 minutes)

### Step 1: Clone the Repository

```bash
git clone https://github.com/Vitalcheffe/gridforge-aws-prompt.git
cd gridforge-aws-prompt
```

### Step 2: Configure Variables

```bash
cd infra/terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your parameters
cat > terraform.tfvars << 'EOF'
utility_name    = "My-Utility"
region          = "af-south-1"
meter_count     = 1000
vpc_cidr        = "10.0.0.0/16"
environment     = "dev"

# Budget controls
monthly_budget_usd = 500
budget_alert_email = "ops@myutility.com"

# Feature flags (toggle modules on/off)
enable_sagemaker      = true
enable_bedrock        = true
enable_greengrass     = true
enable_device_defender = true

# Retention
timestream_memory_retention_hours  = 24
timestream_magnetic_retention_days = 365
EOF
```

### Step 3: Initialize and Validate

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Validate syntax (should return "Success!")
terraform validate

# Preview changes
terraform plan
```

### Step 4: Deploy

```bash
# Deploy all infrastructure
terraform apply -auto-approve

# Note: This creates real AWS resources that incur costs.
# For validation only, use `terraform plan` instead.
```

### Step 5: Verify Deployment

```bash
# Return to repo root
cd ../../..

# Run the smoke test
./scripts/smoke-test.sh

# Generate synthetic test data
python3 scripts/generate-test-data.py --meters 100 --count 10 --output test-data.json

# Estimate monthly costs
./scripts/cost-estimate.sh 1000 af-south-1
```

---

## Option C: Use the Deployment Script (10 minutes)

```bash
# Clone and deploy in one command
git clone https://github.com/Vitalcheffe/gridforge-aws-prompt.git
cd gridforge-aws-prompt

# Deploy with the automated script
# Usage: ./scripts/deploy.sh <environment> <utility_name> <meter_count>
./scripts/deploy.sh dev "My-Utility" 1000
```

The deployment script will:
1. Check all prerequisites (AWS CLI, Terraform, Python)
2. Create the S3 backend for Terraform state
3. Package Lambda functions
4. Run `terraform init`, `terraform plan`, `terraform apply`
5. Verify all outputs and endpoints
6. Run the smoke test

---

## Validation Without Deploying

If you want to verify the prompt output **without spending any money**:

```bash
# Validate Terraform syntax locally
cd infra/terraform
terraform init -backend=false
terraform validate

# Check module structure
ls -la modules/*/main.tf  # Should show 8 modules

# Run the validation script (AWS CLI queries only, no resource creation)
./validate.sh

# Generate test data locally
python3 scripts/generate-test-data.py --meters 100 --count 10
```

---

## What You Should See

After a successful deployment, you should have:

| Resource | How to Verify |
|----------|--------------|
| IoT Thing Group | `aws iot describe-thing-group --thing-group-name gridforge-meters` |
| Timestream Database | `aws timestream-write describe-database --database-name grid-telemetry` |
| Lambda Functions | `aws lambda list-functions --query "Functions[?starts_with(FunctionName, 'gridforge')]"` |
| Step Functions | `aws stepfunctions describe-state-machine --state-machine-arn <arn>` |
| CloudWatch Dashboard | `aws cloudwatch get-dashboard --dashboard-name gridforge-ops` |
| KMS Keys | `aws kms list-keys` |
| Config Rules | `aws configservice describe-config-rules` |
| GuardDuty | `aws guardduty list-detectors` |

---

## Clean Up

```bash
# Destroy all resources (avoid ongoing charges)
cd infra/terraform
terraform destroy -auto-approve

# Delete S3 backend bucket
aws s3 rb s3://gridforge-terraform-state --force

# Delete Lambda packages
rm -rf infra/lambda/*/package/
```

---

## Troubleshooting

| Issue | Solution |
|-------|---------|
| `af-south-1 not available` | Enable the Cape Town region in your AWS account |
| `Bedrock access denied` | Request Bedrock access in the AWS console (takes 24-48h) |
| `Terraform validate fails` | Run `terraform init` first to download providers |
| `Lambda packaging error` | Ensure Python 3.9+ and pip are available |
| `IAM permission denied` | Use an admin-level IAM user for initial deployment |

For more help, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

---

*Quick Start Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
