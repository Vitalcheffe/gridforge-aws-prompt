# GridForge — Troubleshooting Guide

> Common issues and solutions for GridForge deployments

---

## Deployment Issues

### Terraform Init Fails

**Symptom:** `terraform init` returns provider download errors

```
Error: Failed to install provider registry.terraform.io/hashicorp/aws
```

**Solutions:**
1. Check internet connectivity
2. Try with explicit provider version:
   ```bash
   terraform init -upgrade
   ```
3. If behind a corporate proxy, configure Terraform:
   ```bash
   export HTTPS_PROXY="http://proxy:8080"
   export TF_REGISTRY_CLIENT_TIMEOUT=120
   ```

### Terraform Validate Fails

**Symptom:** `terraform validate` returns HCL syntax errors

**Solutions:**
1. Ensure you've run `terraform init` first
2. Check for typos in `terraform.tfvars`
3. Verify all variable types match `variables.tf` declarations
4. Run with verbose logging:
   ```bash
   TF_LOG=DEBUG terraform validate
   ```

### Terraform Plan Shows Too Many Resources

**Symptom:** `terraform plan` shows 50+ resources to create (expected is ~35-40)

**Solutions:**
1. Check if feature flags are set correctly in `terraform.tfvars`:
   ```hcl
   enable_sagemaker      = false  # Disables expensive ML resources
   enable_bedrock        = false  # Disables Bedrock agent
   enable_greengrass     = false  # Disables edge gateway resources
   ```
2. For a minimal deployment, disable all optional features

### Terraform Apply Fails on IAM

**Symptom:** `Error creating IAM role: LimitExceeded`

**Solutions:**
1. Check your account's IAM service quotas:
   ```bash
   aws service-quotas get-service-quota --service-code iam --quota-code L-FE177D64
   ```
2. Request a quota increase if needed
3. Or remove unused roles from the security-compliance module

### af-south-1 Region Not Available

**Symptom:** `Error: InvalidParameterValue: The region af-south-1 is not available`

**Solutions:**
1. Enable the Cape Town region in your AWS account:
   - Go to AWS Console → Account Settings → Regions
   - Enable `af-south-1`
2. Note: Some AWS services are not yet available in af-south-1. Check:
   ```bash
   aws ec2 describe-regions --region-names af-south-1
   ```

### Bedrock Access Denied

**Symptom:** `Error: AccessDeniedException` when creating Bedrock resources

**Solutions:**
1. Request Bedrock access in the AWS console:
   - Navigate to Amazon Bedrock → Model access
   - Request access to Claude 3.5 Sonnet
2. Bedrock access approval takes 24-48 hours
3. As a workaround, disable Bedrock and use rule-based detection:
   ```hcl
   enable_bedrock = false
   ```

---

## Runtime Issues

### IoT Core Messages Not Reaching Lambda

**Symptom:** Lambda invocation count is zero despite meters publishing data

**Solutions:**
1. Verify IoT Core topic rule is active:
   ```bash
   aws iot get-topic-rule --rule-name gridforge-telemetry-to-kinesis
   ```
2. Check IoT Core metrics in CloudWatch:
   - `RuleInvocations` — should be > 0
   - `RuleExecutionFailures` — should be 0
3. Verify Lambda trigger is configured on Kinesis:
   ```bash
   aws lambda get-event-source-mapping --uuid <mapping-uuid>
   ```
4. Check meter MQTT topic matches the rule SQL pattern

### Kinesis Iterator Age Increasing

**Symptom:** CloudWatch alarm `kinesis-iterator-age` triggers (> 60000ms)

**Solutions:**
1. This means Lambda is processing records slower than they arrive
2. Check Lambda concurrent executions:
   ```bash
   aws lambda get-function --function-name gridforge-anomaly-detector \
     --query 'Configuration.[ReservedConcurrentExecutions, Timeout]'
   ```
3. Increase Lambda timeout (max 15 min) or reserved concurrency
4. Consider switching Kinesis to on-demand mode:
   ```hcl
   kinesis_mode = "on_demand"
   ```
5. Scale Kinesis shards:
   ```bash
   aws kinesis update-shard-count \
     --stream-name gridforge-telemetry \
     --target-shard-count 4
   ```

### Timestream Query Timeouts

**Symptom:** Timestream queries take > 30 seconds

**Solutions:**
1. Use time-bound queries (always include `WHERE time > ago(24h)`)
2. Limit results: `LIMIT 1000`
3. Use `time_bin()` for aggregation instead of raw queries
4. Check magnetic store vs memory store hit ratio:
   - Memory store (24h): fast queries
   - Magnetic store (> 24h): slower queries
5. For dashboard queries, use CloudWatch cached metrics instead

### Step Functions Execution Failing

**Symptom:** Step Functions state machine shows failed executions

**Solutions:**
1. Check execution history:
   ```bash
   aws stepfunctions get-execution-history --execution-arn <arn>
   ```
2. Common failure causes:
   - Lambda timeout: Increase to 60s for `IsolateGridSegment`
   - IoT Core command failure: Verify thing exists and is connected
   - SNS publish failure: Verify topic ARN and permissions
3. Check IAM role for Step Functions:
   ```bash
   aws iam get-role-policy --role-name gridforge-step-functions \
     --policy-name step-functions-policy
   ```

### Lambda Cold Start Latency

**Symptom:** First Lambda invocation takes > 3 seconds

**Solutions:**
1. Enable provisioned concurrency for production:
   ```hcl
   lambda_provisioned_concurrency = 1
   ```
2. Use ARM64/Graviton for faster cold starts:
   ```hcl
   lambda_architecture = "arm64"
   ```
3. Minimize deployment package size:
   - Use Lambda Layers for shared dependencies
   - Only include necessary SDK modules
4. For the anomaly detector, use provisioned concurrency during peak hours

---

## Security Issues

### GuardDuty Findings

**Symptom:** GuardDuty reports suspicious activity

**Solutions:**
1. Review findings in Security Hub:
   ```bash
   aws securityhub get-findings \
     --filters '{"SeverityLabel":[{"Value":"HIGH","Comparison":"EQUALS"}]}'
   ```
2. Common legitimate findings:
   - `UnauthorizedAccess:IAMUser/InstanceCredentialExposure` — Check if Lambda roles are over-privileged
   - `Recon:IAMUser/MaliciousIPCaller` — Review source IPs
3. Archive false positives:
   ```bash
   aws guardduty update-findings-feedback \
     --detector-id <id> \
     --finding-ids <id> \
     --feedback NOT_USEFUL
   ```

### Config Rule Non-Compliance

**Symptom:** AWS Config shows non-compliant resources

**Solutions:**
1. List non-compliant resources:
   ```bash
   aws configservice get-compliance-details-by-config-rule \
     --config-rule-name gridforge-encrypted-volumes \
     --compliance-types NON_COMPLIANT
   ```
2. Common non-compliance causes:
   - `encrypted-volumes`: EBS volumes created without KMS encryption
   - `no-public-ingress`: Security group allows 0.0.0.0/0 inbound
   - `s3-bucket-logging-enabled`: S3 access logging not configured
3. Fix by updating Terraform and re-applying

---

## Cost Issues

### Monthly Spend Exceeding Budget

**Symptom:** Cost monitor Lambda sends CRITICAL alert

**Solutions:**
1. Review cost breakdown by service:
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2026-05-01,End=2026-05-28 \
     --granularity MONTHLY \
     --metrics BlendedCost \
     --group-by Type=DIMENSION,Key=SERVICE
   ```
2. Apply right-sizing recommendations:
   - Switch Lambda to arm64 (20% savings)
   - Use SageMaker Serverless instead of real-time endpoint (45% savings)
   - Enable S3 Intelligent-Tiering (30% savings)
   - Use FARGATE_SPOT for batch analytics (70% savings)
3. Reduce retention periods:
   ```hcl
   timestream_magnetic_retention = 90  # Down from 365 days
   ```
4. Disable unused features:
   ```hcl
   enable_sagemaker      = false
   enable_bedrock        = false
   enable_greengrass     = false
   ```

### Unexpected Data Transfer Costs

**Symptom:** Data transfer charges higher than expected

**Solutions:**
1. Use VPC endpoints to avoid NAT Gateway charges:
   ```bash
   aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=com.amazonaws.af-south-1.s3
   ```
2. Enable S3 Transfer Acceleration for edge gateway uploads
3. Use CloudFront for dashboard access (reduces data transfer)

---

## Getting Help

| Issue Type | Resource |
|------------|----------|
| Terraform errors | [HashiCorp Learn](https://learn.hashicorp.com/terraform) |
| AWS service limits | [AWS Service Quotas Console](https://console.aws.amazon.com/servicequotas/) |
| af-south-1 availability | [AWS Regional Services List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) |
| GridForge-specific | Open an issue at [GitHub](https://github.com/Vitalcheffe/gridforge-aws-prompt/issues) |

---

*Troubleshooting Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
