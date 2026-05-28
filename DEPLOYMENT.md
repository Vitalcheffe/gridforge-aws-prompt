# GridForge — Deployment Guide

> Step-by-step deployment instructions for GridForge AWS Smart Grid Infrastructure

---

## Table of Contents

1. [Prerequisites Checklist](#prerequisites-checklist)
2. [10-Step Deployment Instructions](#10-step-deployment-instructions)
3. [Environment Variables Reference](#environment-variables-reference)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Rollback Procedures](#rollback-procedures)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites Checklist

### Required Tools

| Tool | Minimum Version | Purpose | Verification Command |
|------|----------------|---------|---------------------|
| AWS CLI | v2.13+ | AWS resource management | `aws --version` |
| Terraform | v1.5.0+ | Infrastructure as Code | `terraform version` |
| Python | v3.11+ | Lambda functions & scripts | `python3 --version` |
| Docker | v24+ | Greengrass edge testing | `docker --version` |
| Git | v2.40+ | Repository management | `git --version` |
| jq | v1.6+ | JSON processing in scripts | `jq --version` |
| zip | Any | Lambda packaging | `zip --version` |

### AWS Account Requirements

| Requirement | Details | Verification |
|-------------|---------|-------------|
| AWS Account | Active account with billing enabled | `aws sts get-caller-identity` |
| af-south-1 access | Region enabled in account | `aws ec2 describe-regions --region-names af-south-1` |
| IAM permissions | AdministratorAccess or equivalent for initial deployment | `aws iam get-user` |
| Service quotas | IoT Core: 10K+ things, Kinesis: 2+ shards | `aws service-quotas get-service-quota ...` |
| Budget alert | Set up billing alarm before deployment | `aws budgets describe-budgets ...` |
| Bedrock access | Claude 3.5 Sonnet model access enabled | AWS Console → Bedrock → Model access |

### Network Requirements

| Requirement | Details |
|-------------|---------|
| Internet access | For Terraform provider downloads and AWS API calls |
| TLS 1.2+ | Required for all AWS API communications |
| Port 8883 | Outbound for IoT Core MQTT (if testing from VPC) |
| Port 443 | Outbound for all AWS HTTPS API endpoints |

---

## 10-Step Deployment Instructions

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/Vitalcheffe/gridforge-aws-prompt.git
cd gridforge-aws-prompt

# Copy example variables
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars

# Edit with your values
vim infra/terraform/terraform.tfvars
```

### Step 2: Configure AWS Credentials

```bash
# Option A: AWS CLI profile
aws configure --profile gridforge
export AWS_PROFILE=gridforge

# Option B: Environment variables
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=af-south-1

# Verify
aws sts get-caller-identity
```

### Step 3: Create S3 Backend Bucket

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket gridforge-terraform-state-${RANDOM} \
  --region af-south-1 \
  --create-bucket-configuration LocationConstraint=af-south-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket gridforge-terraform-state-XXXXX \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket gridforge-terraform-state-XXXXX \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }]
  }'
```

### Step 4: Package Lambda Functions

```bash
# Package anomaly-detector
cd infra/lambda/anomaly-detector
pip install -r requirements.txt -t .
zip -r ../../../lambda-packages/anomaly-detector.zip .
cd ../../..

# Package grid-event-processor
cd infra/lambda/grid-event-processor
pip install -r requirements.txt -t .
zip -r ../../../lambda-packages/grid-event-processor.zip .
cd ../../..

# Package data-attestation
cd infra/lambda/data-attestation
pip install -r requirements.txt -t .
zip -r ../../../lambda-packages/data-attestation.zip .
cd ../../..

# Package cost-monitor
cd infra/lambda/cost-monitor
pip install -r requirements.txt -t .
zip -r ../../../lambda-packages/cost-monitor.zip .
cd ../../..
```

### Step 5: Initialize Terraform

```bash
cd infra/terraform

# Initialize with S3 backend
terraform init \
  -backend-config="bucket=gridforge-terraform-state-XXXXX" \
  -backend-config="key=gridforge/terraform.tfstate" \
  -backend-config="region=af-south-1" \
  -backend-config="encrypt=true"
```

### Step 6: Plan Deployment

```bash
# Generate execution plan
terraform plan \
  -var-file=terraform.tfvars \
  -out=gridforge.plan

# Review the plan carefully
# Expected: ~85 resources to create
# Estimated monthly cost should appear in outputs
```

### Step 7: Deploy Infrastructure

```bash
# Apply the plan
terraform apply gridforge.plan

# This deploys in order:
# 1. Networking (VPC, subnets, endpoints)
# 2. Security (IAM, KMS, Config)
# 3. IoT Ingestion (IoT Core, Greengrass)
# 4. Data Pipeline (Kinesis, Timestream, S3)
# 5. Analytics ML (Bedrock, SageMaker, Lambda)
# 6. Dashboards Monitoring (QuickSight, CloudWatch)
# 7. Cost Optimization (Budgets)
```

### Step 8: Configure IoT Devices

```bash
# Register smart meters (bulk registration)
aws iot bulk-provision \
  --template-name GridForgeMeterTemplate \
  --parameters file://meter-parameters.json

# Or use the test data generator
python3 scripts/generate-test-data.py --count 100 --region af-south-1
```

### Step 9: Deploy Greengrass Edge (Optional)

```bash
# Build the edge gateway Docker image
cd docker/greengrass-edge
docker build -t gridforge-greengrass:latest .

# Deploy to edge devices
# For Raspberry Pi / ARM devices:
docker save gridforge-greengrass:latest | gzip > greengrass-edge.tar.gz
scp greengrass-edge.tar.gz edge-device:/opt/greengrass/

# On edge device:
docker load < /opt/greengrass/greengrass-edge.tar.gz
docker run -d --name greengrass \
  -v /opt/greengrass/config:/config \
  -e AWS_REGION=af-south-1 \
  -e IOT_ENDPOINT=$(terraform output -raw iot_endpoint) \
  gridforge-greengrass:latest
```

### Step 10: Verify Deployment

```bash
# Run comprehensive validation
cd ../../..
bash scripts/validate.sh

# Run smoke test
bash scripts/smoke-test.sh

# Generate test data and verify end-to-end flow
python3 scripts/generate-test-data.py --count 10 --region af-south-1 --inject
```

---

## Environment Variables Reference

### Required Variables

| Variable | Description | Example | Set In |
|----------|-------------|---------|--------|
| `AWS_REGION` | AWS deployment region | `af-south-1` | Environment / tfvars |
| `AWS_PROFILE` | AWS CLI profile name | `gridforge` | Environment |
| `TF_VAR_utility_name` | Utility company name | `VRA-Ghana` | terraform.tfvars |
| `TF_VAR_meter_count` | Number of smart meters | `10000` | terraform.tfvars |
| `TF_VAR_budget_limit` | Monthly budget limit (USD) | `1000` | terraform.tfvars |

### Optional Variables

| Variable | Description | Default | Set In |
|----------|-------------|---------|--------|
| `TF_VAR_environment` | Deployment environment | `production` | terraform.tfvars |
| `TF_VAR_vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | terraform.tfvars |
| `TF_VAR_az_count` | Number of AZs | `3` | terraform.tfvars |
| `TF_VAR_enable_greengrass` | Deploy Greengrass edge | `true` | terraform.tfvars |
| `TF_VAR_enable_sagemaker` | Deploy SageMaker endpoint | `true` | terraform.tfvars |
| `TF_VAR_enable_bedrock` | Enable Bedrock integration | `true` | terraform.tfvars |
| `TF_VAR_timestream_memory_retention` | Memory store retention (hours) | `24` | terraform.tfvars |
| `TF_VAR_timestream_magnetic_retention` | Magnetic store retention (days) | `365` | terraform.tfvars |
| `TF_VAR_kinesis_shard_count` | Kinesis shards (provisioned mode) | `2` | terraform.tfvars |
| `TF_VAR_kinesis_mode` | Kinesis capacity mode | `on_demand` | terraform.tfvars |
| `TF_VAR_lambda_architecture` | Lambda CPU architecture | `arm64` | terraform.tfvars |
| `TF_VAR_alert_email` | Operations alert email | - | terraform.tfvars |
| `TF_VAR_cost_alert_threshold` | Budget alert threshold (USD) | `500` | terraform.tfvars |

---

## Post-Deployment Verification

### Infrastructure Verification Checklist

| # | Check | Command | Expected Result |
|---|-------|---------|----------------|
| 1 | VPC created | `aws ec2 describe-vpcs --filters Name=tag:Name,Values=gridforge-*` | 1 VPC, CIDR 10.0.0.0/16 |
| 2 | Subnets created | `aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id>` | 9 subnets (3 AZ × 3 tiers) |
| 3 | IoT Thing Group exists | `aws iot describe-thing-group --thing-group-name gridforge-meters` | Thing group with correct properties |
| 4 | Kinesis stream active | `aws kinesis describe-stream --stream-name gridforge-telemetry` | ACTIVE, 2 shards |
| 5 | Timestream database exists | `aws timestream-write describe-database --database-name grid-telemetry` | Database with correct retention |
| 6 | Lambda functions deployed | `aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `gridforge`)]'` | 4 functions, arm64 |
| 7 | Step Functions state machine | `aws stepfunctions describe-state-machine --state-machine-arn <arn>` | ACTIVE |
| 8 | CloudWatch alarms | `aws cloudwatch describe-alarms --alarm-name-prefix gridforge-` | 4 alarms, OK state |
| 9 | KMS keys | `aws kms list-aliases --query 'Aliases[?starts_with(AliasName, `alias/gridforge`)]'` | 4 keys with rotation |
| 10 | GuardDuty enabled | `aws guardduty list-detectors` | 1 detector, ACTIVE |
| 11 | Security Hub enabled | `aws securityhub describe-hub` | Hub exists |
| 12 | Budget created | `aws budgets describe-budgets --account-id <account-id>` | Budget at configured limit |

### Functional Verification

```bash
# 1. Test IoT message flow
aws iot-data publish \
  --topic "grid/telemetry/METER-TEST-001" \
  --payload '{"meter_id":"METER-TEST-001","voltage":220,"current":15.5,"frequency":50.0,"power_factor":0.95,"timestamp":"2026-01-15T10:00:00Z"}'

# 2. Verify Timestream ingestion (wait 30 seconds)
aws timestream-query query \
  --query-string "SELECT * FROM grid-telemetry.meter-readings WHERE meter_id = 'METER-TEST-001' ORDER BY time DESC LIMIT 1"

# 3. Test anomaly detection (send critical voltage)
aws iot-data publish \
  --topic "grid/telemetry/METER-TEST-001" \
  --payload '{"meter_id":"METER-TEST-001","voltage":150,"current":15.5,"frequency":50.0,"power_factor":0.95,"timestamp":"2026-01-15T10:01:00Z"}'

# 4. Check SNS notification was sent
aws sns list-subscriptions-by-topic --topic-arn <critical-grid-events-arn>

# 5. Verify QuickSight dashboard
# Open the QuickSight URL from Terraform output
```

---

## Rollback Procedures

### Partial Rollback (Single Module)

```bash
# Rollback a specific module
terraform destroy -target=module.analytics_ml

# Re-apply with corrected configuration
terraform apply -target=module.analytics_ml
```

### Full Rollback (Complete Destruction)

```bash
# ⚠️ WARNING: This destroys ALL resources
# Use the teardown script for a controlled destruction
bash scripts/teardown.sh

# Or manually:
terraform destroy -var-file=terraform.tfvars

# Verify all resources are destroyed
aws resourcegroupstaggingapi get-resources --tag-filter Key=Project,Values=GridForge
```

### State Recovery (Terraform State Corruption)

```bash
# List Terraform state versions (if S3 versioning enabled)
aws s3api list-object-versions \
  --bucket gridforge-terraform-state-XXXXX \
  --prefix gridforge/terraform.tfstate

# Restore previous version
aws s3api copy-object \
  --bucket gridforge-terraform-state-XXXXX \
  --copy-source gridforge-terraform-state-XXXXX/gridforge/terraform.tfstate?versionId=XXXXX \
  --key gridforge/terraform.tfstate

# Re-initialize and verify
terraform init
terraform plan  # Should show no changes
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Terraform Init Fails — S3 Backend Access

```
Error: Failed to get existing workspaces: AccessDenied
```

**Solution**: Verify S3 bucket permissions and region:
```bash
aws s3 ls s3://gridforge-terraform-state-XXXXX/ --region af-south-1
```

#### Issue 2: Lambda Deployment Package Too Large

```
Error: Lambda deployment package too large (exceeds 50MB unzipped)
```

**Solution**: Use Lambda Layers for shared dependencies:
```bash
# Create a Lambda Layer for common dependencies
mkdir -p layer/python
pip install boto3 -t layer/python/
cd layer && zip -r ../lambda-layer.zip . && cd ..
aws lambda publish-layer-version \
  --layer-name gridforge-common \
  --zip-file fileb://lambda-layer.zip \
  --compatible-runtimes python3.11 \
  --compatible-architectures arm64
```

#### Issue 3: IoT Core Certificate Limit

```
Error: LimitExceededException: Cannot create more than 1000 certificates
```

**Solution**: Request a service quota increase:
```bash
aws service-quotas request-service-quota-increase \
  --service-code iot \
  --quota-code L-C63515B5 \
  --desired-value 15000
```

#### Issue 4: Bedrock Model Access Not Enabled

```
Error: ValidationException: The model anthropic.claude-3-5-sonnet is not available
```

**Solution**: Enable model access in Bedrock console:
1. Go to AWS Console → Amazon Bedrock
2. Navigate to Model Access
3. Request access to Claude 3.5 Sonnet
4. Wait for approval (usually immediate)

#### Issue 5: Kinesis Shard Limit in af-south-1

```
Error: LimitExceededException: Rate exceeded for shard creation
```

**Solution**: Use on-demand mode instead of provisioned:
```hcl
resource "aws_kinesis_stream" "telemetry" {
  name             = "gridforge-telemetry"
  stream_mode_details {
    stream_mode = "ON_DEMAND"  # Auto-scales
  }
}
```

#### Issue 6: Timestream Write Throttling

```
Error: ThrottlingException: Rate exceeded
```

**Solution**: Batch writes and reduce write frequency:
- Use Greengrass aggregation (5s → 1min)
- Batch Timestream writes (up to 100 records per API call)
- Increase memory store write capacity

---

*Deployment Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
