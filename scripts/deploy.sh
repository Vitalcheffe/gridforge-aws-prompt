#!/bin/bash
# GridForge — Full Deployment Script
# AWS Smart Grid Infrastructure Deployer for Emerging Markets
# Usage: ./scripts/deploy.sh [environment] [utility_name] [meter_count]

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/infra/terraform"

ENVIRONMENT="${1:-production}"
UTILITY_NAME="${2:-gridforge-utility}"
METER_COUNT="${3:-10000}"
AWS_REGION="${AWS_REGION:-af-south-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Functions
# ============================================================

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        log_error "terraform not found. Install from https://terraform.io"
        missing=1
    else
        local tf_version=$(terraform version -json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('terraform_version','0'))" 2>/dev/null || echo "0")
        log_ok "terraform $tf_version"
    fi
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Install from https://aws.amazon.com/cli/"
        missing=1
    else
        log_ok "AWS CLI $(aws --version 2>&1 | head -1)"
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "python3 not found"
        missing=1
    else
        log_ok "python3 $(python3 --version)"
    fi
    
    # Check AWS authentication
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure'"
        missing=1
    else
        local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        log_ok "AWS authenticated (Account: $account_id)"
    fi
    
    # Check af-south-1 region
    if ! aws ec2 describe-availability-zones --region af-south-1 &> /dev/null; then
        log_warn "af-south-1 region may not be enabled. Enable it in AWS Console."
    else
        log_ok "af-south-1 region available"
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Prerequisites check failed. Fix the issues above and retry."
        exit 1
    fi
    
    log_ok "All prerequisites met"
}

create_s3_backend() {
    log_info "Creating S3 backend for Terraform state..."
    
    local bucket_name="gridforge-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
    
    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        log_ok "S3 backend bucket exists: $bucket_name"
    else
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --region af-south-1 \
            --create-bucket-configuration LocationConstraint=af-south-1 \
            2>/dev/null
        
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}}]
            }'
        
        log_ok "Created S3 backend: $bucket_name"
    fi
    
    # Create DynamoDB lock table
    if aws dynamodb describe-table --table-name gridforge-terraform-lock --region af-south-1 &>/dev/null; then
        log_ok "DynamoDB lock table exists"
    else
        aws dynamodb create-table \
            --table-name gridforge-terraform-lock \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region af-south-1 2>/dev/null
        
        log_ok "Created DynamoDB lock table"
    fi
}

package_lambda_functions() {
    log_info "Packaging Lambda functions..."
    
    local lambda_dir="$PROJECT_DIR/infra/lambda"
    
    for func_dir in "$lambda_dir"/*/; do
        func_name=$(basename "$func_dir")
        zip_file="$TF_DIR/lambda-${func_name}.zip"
        
        if [ -f "$func_dir/index.py" ]; then
            cd "$func_dir"
            zip -r "$zip_file" index.py requirements.txt 2>/dev/null || zip -r "$zip_file" index.py 2>/dev/null
            cd "$PROJECT_DIR"
            log_ok "Packaged Lambda: $func_name"
        fi
    done
}

run_terraform() {
    log_info "Running Terraform..."
    
    cd "$TF_DIR"
    
    # Initialize
    log_info "terraform init..."
    terraform init -upgrade
    
    # Create workspace if needed
    if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
        terraform workspace new "$ENVIRONMENT"
    fi
    terraform workspace select "$ENVIRONMENT"
    
    # Create terraform.tfvars
    cat > terraform.tfvars <<EOF
aws_region    = "$AWS_REGION"
environment   = "$ENVIRONMENT"
utility_name  = "$UTILITY_NAME"
meter_count   = $METER_COUNT
EOF
    
    # Plan
    log_info "terraform plan..."
    terraform plan -out=tfplan -var-file=terraform.tfvars
    
    # Show plan summary
    local plan_summary=$(terraform show -json tfplan 2>/dev/null | python3 -c "
import json, sys
plan = json.load(sys.stdin)
create = sum(1 for c in plan.get('resource_changes', []) if c.get('change', {}).get('actions') == ['create'])
update = sum(1 for c in plan.get('resource_changes', []) if 'update' in c.get('change', {}).get('actions', []))
delete = sum(1 for c in plan.get('resource_changes', []) if 'delete' in c.get('change', {}).get('actions', []))
print(f'Create: {create}, Update: {update}, Delete: {delete}')
" 2>/dev/null || echo "Plan summary unavailable")
    log_info "Plan: $plan_summary"
    
    # Apply
    log_info "terraform apply..."
    terraform apply tfplan
    
    log_ok "Terraform apply complete"
}

post_deploy_verification() {
    log_info "Running post-deployment verification..."
    
    cd "$TF_DIR"
    
    # Get outputs
    local iot_endpoint=$(terraform output -raw iot_endpoint 2>/dev/null || echo "N/A")
    local dashboard_url=$(terraform output -raw quicksight_dashboard_url 2>/dev/null || echo "N/A")
    local vpc_id=$(terraform output -raw vpc_id 2>/dev/null || echo "N/A")
    
    echo ""
    echo "============================================================"
    echo "  GridForge Deployment Complete!"
    echo "============================================================"
    echo ""
    echo "  Region:         $AWS_REGION"
    echo "  Environment:    $ENVIRONMENT"
    echo "  Utility:        $UTILITY_NAME"
    echo "  Meter Count:    $METER_COUNT"
    echo "  VPC ID:         $vpc_id"
    echo "  IoT Endpoint:   $iot_endpoint"
    echo "  Dashboard:      $dashboard_url"
    echo ""
    echo "  Next steps:"
    echo "  1. Register smart meters with IoT Core"
    echo "  2. Deploy Greengrass to edge gateways"
    echo "  3. Access QuickSight dashboard for monitoring"
    echo "  4. Run smoke test: ./scripts/smoke-test.sh"
    echo "============================================================"
}

# ============================================================
# Main
# ============================================================

echo ""
echo "============================================================"
echo "  GridForge — AWS Smart Grid Infrastructure Deployer"
echo "  Deploying to $AWS_REGION for $UTILITY_NAME"
echo "============================================================"
echo ""

check_prerequisites
create_s3_backend
package_lambda_functions
run_terraform
post_deploy_verification
