# GridForge — Security & Compliance Document

> Comprehensive security architecture and compliance mapping for GridForge AWS Smart Grid Infrastructure

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [NERC CIP Compliance Mapping](#nerc-cip-compliance-mapping)
3. [Threat Model](#threat-model)
4. [IAM Role Breakdown](#iam-role-breakdown)
5. [Encryption Strategy](#encryption-strategy)
6. [Compliance Checklist](#compliance-checklist)
7. [Network Security](#network-security)
8. [Incident Response](#incident-response)

---

## Security Overview

GridForge implements a defense-in-depth security model aligned with the AWS Well-Architected Framework Security Pillar and NERC CIP (North American Electric Reliability Corporation Critical Infrastructure Protection) standards. While NERC CIP is a North American standard, it represents the gold standard for bulk electric system cybersecurity and is increasingly referenced by African regulatory bodies.

### Security Principles

1. **Zero Trust**: Every request is authenticated and authorized, regardless of network location
2. **Least Privilege**: 12 IAM roles with minimum required permissions per module
3. **Defense in Depth**: Multiple security layers (network, application, data, identity)
4. **Encryption Everywhere**: KMS CMKs for all data at rest and in transit
5. **Continuous Monitoring**: GuardDuty, Security Hub, Config, CloudTrail
6. **Automated Response**: Step Functions orchestrate security incident workflows

---

## NERC CIP Compliance Mapping

| NERC CIP Standard | Requirement | AWS Control | Terraform Resource | Verification |
|-------------------|-------------|-------------|-------------------|--------------|
| **CIP-002-5.1** | BES Cyber System identification | AWS Config: resource inventory | `aws_config_config_rule` (required-tags) | `aws configservice get-compliance-details-by-config-rule` |
| **CIP-003-7** | Security management controls | IAM policies + SCPs | `aws_iam_policy`, `aws_iam_role_policy_attachment` | `aws iam get-policy-version` |
| **CIP-004-6** | Personnel & training | IAM MFA enforcement | `aws_iam_account_password_policy`, `aws_iam_user_login_profile` | `aws iam get-account-summary` (MFA devices) |
| **CIP-005-5** | Electronic security perimeters | VPC + Security Groups + NACLs | `aws_vpc`, `aws_security_group`, `aws_network_acl` | `aws ec2 describe-security-groups` |
| **CIP-006-6** | Physical security | AWS data center (AWS responsibility) | N/A | AWS SOC 2 Type II report |
| **CIP-007-6** | System security management | SSM Patch Manager + Inspector | `aws_ssm_association`, `aws_inspector2_enabler` | `aws ssm list-instance-patches` |
| **CIP-008-6** | Incident response & reporting | GuardDuty + Security Hub + Step Functions | `aws_guardduty_detector`, `aws_securityhub_standards_control` | `aws guardduty list-findings` |
| **CIP-009-6** | Recovery planning | AWS Backup + Cross-region replication | `aws_backup_plan`, `aws_backup_selection` | `aws backup list-recovery-points-by-backup-vault` |
| **CIP-010-3** | Configuration change management | CloudTrail + Config + Change detection | `aws_cloudtrail`, `aws_config_config_rule` | `aws cloudtrail lookup-events` |
| **CIP-011-2** | Information protection | KMS encryption + VPC endpoints + S3 Block Public Access | `aws_kms_key`, `aws_vpc_endpoint`, `aws_s3_bucket_public_access_block` | `aws kms describe-key`, `aws s3api get-bucket-encryption` |
| **CIP-013-1** | Supply chain risk management | Code signing + Artifact verification | `aws_signer_signing_profile`, Lambda layer verification | `aws signer list-signing-profiles` |

---

## Threat Model

### Top 5 Threats for Grid Infrastructure on AWS

#### Threat 1: Compromised Smart Meter (Supply Chain Attack)

| Attribute | Detail |
|-----------|--------|
| **Threat Actor** | Nation-state or advanced persistent threat (APT) |
| **Attack Vector** | Firmware modification during manufacturing or OTA update |
| **Impact** | False telemetry injection, unauthorized grid commands, data exfiltration |
| **Likelihood** | Medium — increasing with IoT device proliferation |
| **Mitigation** | Device Defender anomaly detection, certificate-based mutual TLS, ACM Private CA for device certificate management, IoT Core policy restrictions (per-device scope), Greengrass component signing verification |
| **Detection** | Device Defender audit: daily scan for anomalous behavior (msg rate, connection pattern), CloudWatch alarm on iot-message-rate-drop or iot-message-rate-spike |
| **Response** | Automated: Device Defender → EventBridge → Step Functions → Revoke certificate + Quarantine device in Thing Group |

#### Threat 2: Data Exfiltration (Insider or External)

| Attribute | Detail |
|-----------|--------|
| **Threat Actor** | Malicious insider or compromised credentials |
| **Attack Vector** | Unauthorized S3 download, Timestream query export, Lambda data access |
| **Impact** | Customer PII exposure, grid topology disclosure, competitive intelligence leak |
| **Likelihood** | Medium — insider threats account for 30% of data breaches |
| **Mitigation** | VPC endpoints (no internet egress for data services), S3 Block Public Access, KMS encryption (data unreadable without CMK access), CloudTrail data event logging for S3, Lambda execution role scoping (no s3:GetObject on raw telemetry bucket) |
| **Detection** | GuardDuty S3 protection (unusual download patterns), CloudTrail log monitoring, Macie for PII discovery |
| **Response** | Automated: GuardDuty finding → Security Hub → EventBridge → Step Functions → Revoke IAM session + Notify security team via SNS |

#### Threat 3: DDoS Attack on IoT Endpoint

| Attribute | Detail |
|-----------|--------|
| **Threat Actor** | External attacker, hacktivist, or competitor |
| **Attack Vector** | Volumetric MQTT CONNECT flood or HTTP/2 request flood on IoT endpoint |
| **Impact** | Legitimate meters unable to connect, telemetry gaps, delayed anomaly detection |
| **Likelihood** | High — IoT endpoints are common DDoS targets |
| **Mitigation** | AWS Shield Standard (automatic, no config), IoT Core throttling limits (per-client and account-level), WAF on API Gateway (if REST API exposed), CloudFront distribution for any public endpoints |
| **Detection** | CloudWatch alarm on IoT connection rate, VPC Flow Logs analysis, Shield Advanced metrics |
| **Response** | Automatic: Shield Standard mitigates common attacks; for advanced attacks, engage AWS DDoS response team (DRT) via Shield Advanced |

#### Threat 4: Insider Threat (Privileged Access Abuse)

| Attribute | Detail |
|-----------|--------|
| **Threat Actor** | Disgruntled employee or compromised admin credentials |
| **Attack Vector** | IAM role assumption with excessive permissions, manual infrastructure changes |
| **Impact** | Unauthorized configuration changes, data deletion, service disruption |
| **Likelihood** | Medium — 30% of breaches involve insider actions |
| **Mitigation** | 12 scoped IAM roles (no single role has full access), MFA required for all IAM users, CloudTrail logs all API calls (immutable S3 bucket with Object Lock), Config rules detect unauthorized changes, AWS Organizations SCPs prevent dangerous actions (e.g., no s3:DeleteBucket) |
| **Detection** | CloudTrail anomalous API call detection, GuardDuty credential compromise detection, Config rule drift detection |
| **Response** | Automated: GuardDuty → Security Hub → EventBridge → SNS alert to security team + temporary IAM session revocation |

#### Threat 5: Supply Chain Attack on Lambda Dependencies

| Attribute | Detail |
|-----------|--------|
| **Threat Actor** | Package maintainer with malicious intent or compromised package |
| **Attack Vector** | Typosquatting or dependency confusion in pip packages |
| **Impact** | Code execution within Lambda, data access, lateral movement |
| **Likelihood** | Low-Medium — increasing trend in software supply chain attacks |
| **Mitigation** | Minimal dependencies (requirements.txt limited to AWS SDK + essential packages), Lambda layer pinning with SHA256 hash verification, AWS Signer for code signing, S3 bucket policy restricts Lambda deployment package sources |
| **Detection** | Lambda execution behavior monitoring via CloudWatch, GuardDuty Lambda protection (if available), Code scanning in CI/CD pipeline |
| **Response** | Manual: Review Lambda execution logs, rollback to previous deployment version, update dependency versions |

---

## IAM Role Breakdown

### Role 1: GridForge-IoT-Core

```json
{
  "RoleName": "GridForge-IoT-Core",
  "Purpose": "IoT device management and message routing",
  "TrustPolicy": "iot.amazonaws.com",
  "Permissions": [
    "iot:Connect",
    "iot:Publish",
    "iot:Subscribe",
    "iot:Receive",
    "iot:GetThingShadow",
    "iot:UpdateThingShadow"
  ],
  "Constraints": {
    "Condition": "iot:Connection.Thing.IsAttached = true",
    "Resource": "arn:aws:iot:af-south-1:*:thing/gridforge-*"
  }
}
```

### Role 2: GridForge-Greengrass

```json
{
  "RoleName": "GridForge-Greengrass",
  "Purpose": "Edge gateway deployment and management",
  "TrustPolicy": "greengrass.amazonaws.com",
  "Permissions": [
    "greengrass:CreateDeployment",
    "greengrass:GetDeploymentStatus",
    "greengrass:ListComponentVersions",
    "iot:GetThingShadow",
    "iot:UpdateThingShadow",
    "s3:GetObject (Greengrass artifacts bucket only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 3: GridForge-Kinesis-Writer

```json
{
  "RoleName": "GridForge-Kinesis-Writer",
  "Purpose": "IoT Rule → Kinesis stream ingestion",
  "TrustPolicy": "iot.amazonaws.com",
  "Permissions": [
    "kinesis:PutRecord",
    "kinesis:PutRecords",
    "kinesis:DescribeStream"
  ],
  "Constraints": {
    "Resource": "arn:aws:kinesis:af-south-1:*:stream/gridforge-*"
  }
}
```

### Role 4: GridForge-Timestream-Writer

```json
{
  "RoleName": "GridForge-Timestream-Writer",
  "Purpose": "IoT Rule → Timestream write operations",
  "TrustPolicy": "iot.amazonaws.com",
  "Permissions": [
    "timestream:WriteRecords",
    "timestream:DescribeEndpoints"
  ],
  "Constraints": {
    "Resource": "arn:aws:timestream:af-south-1:*:database/gridforge-*"
  }
}
```

### Role 5: GridForge-Lambda-Anomaly

```json
{
  "RoleName": "GridForge-Lambda-Anomaly",
  "Purpose": "Anomaly detection processing from Kinesis",
  "TrustPolicy": "lambda.amazonaws.com",
  "Permissions": [
    "kinesis:GetRecords",
    "kinesis:GetShardIterator",
    "kinesis:DescribeStream",
    "sns:Publish (critical-grid-events topic only)",
    "events:PutEvents (gridforge-events bus only)",
    "sagemaker:InvokeEndpoint (gridforge-* endpoint only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 6: GridForge-Lambda-EventProc

```json
{
  "RoleName": "GridForge-Lambda-EventProc",
  "Purpose": "Grid event classification and notification",
  "TrustPolicy": "lambda.amazonaws.com",
  "Permissions": [
    "dynamodb:PutItem (grid-incidents table only)",
    "dynamodb:Query",
    "sns:Publish (ops-alerts topic only)",
    "ses:SendEmail (verified sender only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 7: GridForge-StepFunctions

```json
{
  "RoleName": "GridForge-StepFunctions",
  "Purpose": "Grid response workflow orchestration",
  "TrustPolicy": "states.amazonaws.com",
  "Permissions": [
    "lambda:InvokeFunction (gridforge-* functions only)",
    "iot:Publish (grid/commands/* topics only)",
    "sns:Publish (critical-grid-events topic only)",
    "dynamodb:PutItem (grid-incidents table only)",
    "bedrock:InvokeModel (claude-3-5-sonnet only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 8: GridForge-Bedrock-Invoke

```json
{
  "RoleName": "GridForge-Bedrock-Invoke",
  "Purpose": "Bedrock model invocation for grid analysis",
  "TrustPolicy": "bedrock.amazonaws.com",
  "Permissions": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:Retrieve (grid-analyst knowledge base only)"
  ],
  "Constraints": {
    "Resource": "arn:aws:bedrock:af-south-1::foundation-model/anthropic.claude-3-5-sonnet-*"
  }
}
```

### Role 9: GridForge-SageMaker

```json
{
  "RoleName": "GridForge-SageMaker",
  "Purpose": "ML model inference for predictive maintenance",
  "TrustPolicy": "sagemaker.amazonaws.com",
  "Permissions": [
    "sagemaker:InvokeEndpoint",
    "s3:GetObject (model artifacts bucket only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 10: GridForge-QuickSight

```json
{
  "RoleName": "GridForge-QuickSight",
  "Purpose": "Dashboard data access and rendering",
  "TrustPolicy": "quicksight.amazonaws.com",
  "Permissions": [
    "timestream:Select",
    "timestream:DescribeEndpoints",
    "s3:GetObject (curated data bucket only)",
    "athena:StartQueryExecution",
    "athena:GetQueryResults"
  ]
}
```

### Role 11: GridForge-Config-Audit

```json
{
  "RoleName": "GridForge-Config-Audit",
  "Purpose": "Compliance evaluation and reporting",
  "TrustPolicy": "config.amazonaws.com",
  "Permissions": [
    "config:PutEvaluations",
    "config:StartConfigRulesEvaluation",
    "securityhub:BatchImportFindings",
    "securityhub:GetFindings",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### Role 12: GridForge-Cost-Monitor

```json
{
  "RoleName": "GridForge-Cost-Monitor",
  "Purpose": "Cost tracking and optimization recommendations",
  "TrustPolicy": "lambda.amazonaws.com",
  "Permissions": [
    "budgets:DescribeBudgets",
    "budgets:ViewBudget",
    "ce:GetCostAndUsage",
    "ce:GetReservationCoverage",
    "ce:GetRightsizingRecommendation",
    "sns:Publish (cost-alerts topic only)",
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

---

## Encryption Strategy

### At-Rest Encryption

| Data Store | Encryption Method | Key Type | Rotation | Terraform Resource |
|------------|------------------|----------|----------|-------------------|
| IoT Core message payload | KMS CMK: `gridforge-iot-key` | AWS owned → Customer managed | 90 days | `aws_kms_key` + `aws_iot_topic_rule` |
| Timestream database | KMS CMK: `gridforge-timestream-key` | Customer managed | 90 days | `aws_kms_key` + `aws_timestreamwrite_database` |
| S3 data lake | KMS CMK: `gridforge-s3-key` | Customer managed | 90 days | `aws_kms_key` + `aws_s3_bucket_server_side_encryption_configuration` |
| CloudWatch Logs | KMS CMK: `gridforge-logs-key` | Customer managed | 90 days | `aws_kms_key` + `aws_cloudwatch_log_group` |
| DynamoDB (incidents) | AWS owned key (default) | AWS managed | Automatic | `aws_dynamodb_table` (encrypted by default) |
| Lambda environment vars | KMS CMK: `gridforge-lambda-key` | Customer managed | 90 days | `aws_kms_key` + `aws_lambda_function` (kms_key_arn) |

### In-Transit Encryption

| Connection | Protocol | Certificate | Enforcement |
|------------|----------|-------------|-------------|
| Smart meter → IoT Core | MQTT v5 over TLS 1.2+ | ACM Private CA issued | `aws_iot_policy` requires TLS |
| Greengrass → IoT Core | MQTT over TLS 1.2+ | X.509 device certificate | Mutual TLS required |
| Lambda → AWS services | TLS 1.2+ via VPC endpoints | AWS managed | VPC endpoint policies |
| QuickSight → Timestream | TLS 1.2+ | AWS managed | Default |
| API Gateway (if exposed) | HTTPS only | ACM public certificate | `aws_api_gateway_domain_name` |
| S3 access | TLS 1.2+ enforced | AWS managed | `aws_s3_bucket_policy` (aws:SecureTransport) |

### Key Management Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    KMS Key Hierarchy                        │
│                                                            │
│  ┌──────────────────┐   ┌──────────────────────────────┐  │
│  │ AWS Managed Key  │   │    Customer Managed Keys      │  │
│  │ (default/aws)    │   │                                │  │
│  │                  │   │  ┌──────────────────────────┐ │  │
│  │ Used for:        │   │  │ gridforge-iot-key        │ │  │
│  │ - DynamoDB       │   │  │ Alias: iot-key           │ │  │
│  │ - Default S3     │   │  │ Rotation: 90 days        │ │  │
│  │                  │   │  │ Policy: IoT Core only     │ │  │
│  └──────────────────┘   │  └──────────────────────────┘ │  │
│                          │  ┌──────────────────────────┐ │  │
│                          │  │ gridforge-timestream-key │ │  │
│                          │  │ Alias: timestream-key    │ │  │
│                          │  │ Rotation: 90 days        │ │  │
│                          │  │ Policy: Timestream only  │ │  │
│                          │  └──────────────────────────┘ │  │
│                          │  ┌──────────────────────────┐ │  │
│                          │  │ gridforge-s3-key         │ │  │
│                          │  │ Alias: s3-key            │ │  │
│                          │  │ Rotation: 90 days        │ │  │
│                          │  │ Policy: S3 + Firehose    │ │  │
│                          │  └──────────────────────────┘ │  │
│                          │  ┌──────────────────────────┐ │  │
│                          │  │ gridforge-logs-key       │ │  │
│                          │  │ Alias: logs-key          │ │  │
│                          │  │ Rotation: 90 days        │ │  │
│                          │  │ Policy: CloudWatch only  │ │  │
│                          │  └──────────────────────────┘ │  │
│                          └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## Compliance Checklist

### Pre-Deployment Security Checklist

| # | Check | Status | Verification Command |
|---|-------|--------|---------------------|
| 1 | All IAM roles follow least privilege | ☐ | `aws iam get-policy-version --policy-arn ...` |
| 2 | KMS CMKs created with 90-day rotation | ☐ | `aws kms get-key-rotation-status --key-id ...` |
| 3 | S3 buckets have Block Public Access enabled | ☐ | `aws s3api get-public-access-block --bucket ...` |
| 4 | CloudTrail enabled (multi-region) | ☐ | `aws cloudtrail describe-trails` |
| 5 | GuardDuty enabled with S3 + IoT protection | ☐ | `aws guardduty list-detectors` |
| 6 | Security Hub enabled with NERC CIP standard | ☐ | `aws securityhub describe-hub` |
| 7 | Config Rules created for NERC CIP mapping | ☐ | `aws configservice describe-config-rules` |
| 8 | VPC Flow Logs enabled | ☐ | `aws ec2 describe-flow-logs --filter ...` |
| 9 | All Lambda functions use arm64 (Graviton) | ☐ | `aws lambda get-function-configuration ...` |
| 10 | No secrets in Terraform state | ☐ | Code review + tfsec scan |
| 11 | NACLs block inbound to isolated subnets | ☐ | `aws ec2 describe-network-acls` |
| 12 | VPC endpoints for all data services | ☐ | `aws ec2 describe-vpc-endpoints` |
| 13 | IoT Core policies require TLS 1.2+ | ☐ | `aws iot get-policy --policy-name ...` |
| 14 | S3 bucket policy requires SecureTransport | ☐ | `aws s3api get-bucket-policy --bucket ...` |
| 15 | Lambda environment variables encrypted | ☐ | `aws lambda get-function-configuration ...` |

### Post-Deployment Security Verification

```bash
# Run the security validation subset
bash scripts/validate.sh --security-only

# Check NERC CIP compliance score
aws securityhub get-insight-results --insight-arn arn:aws:securityhub:af-south-1::...

# Verify no public resources
aws ec2 describe-security-groups --filters Name=group-name,Values=default --query 'SecurityGroups[0].IpPermissions'

# Check encryption status
aws kms get-key-rotation-status --key-id alias/gridforge-iot-key
aws kms get-key-rotation-status --key-id alias/gridforge-timestream-key
aws kms get-key-rotation-status --key-id alias/gridforge-s3-key
aws kms get-key-rotation-status --key-id alias/gridforge-logs-key

# Verify GuardDuty findings
aws guardduty list-findings --detector-id <detector-id> --finding-criterion severity=HIGH
```

---

## Network Security

### Security Group Rules

| Security Group | Inbound | Outbound | Attached To |
|---------------|---------|----------|-------------|
| sg-gridforge-lambda | None (VPC endpoint only) | VPC endpoints + SNS | Lambda ENIs |
| sg-gridforge-sagemaker | sg-gridforge-lambda:443 | VPC endpoints | SageMaker VPC endpoints |
| sg-gridforge-alb | 0.0.0.0/0:443 (HTTPS only) | sg-gridforge-ecs:8080 | ALB |
| sg-gridforge-greengrass | None (outbound only) | IoT Core endpoint:8883 | Greengrass (via IoT) |

### Network ACL Rules

| Subnet Tier | Inbound Rules | Outbound Rules |
|-------------|--------------|----------------|
| Public | Allow 443 (HTTPS), 22 (SSH from bastion only) | Allow all |
| Private | Allow from Public SG only | Allow to VPC endpoints + internet (via NAT) |
| Isolated | Allow from Private SG only | Allow to VPC endpoints only (no internet) |

---

## Incident Response

### Automated Response Workflow

When GuardDuty detects a security finding:

1. **Detection**: GuardDuty → Security Hub finding
2. **Enrichment**: EventBridge rule matches finding severity ≥ MEDIUM
3. **Notification**: SNS topic `critical-grid-events` → PagerDuty / Ops team
4. **Triage**: Step Functions `security-incident-responder`:
   - If credential compromise: Revoke IAM sessions
   - If compromised device: Quarantine IoT Thing + Revoke certificate
   - If data exfiltration: Block S3 access + Enable access logging
5. **Documentation**: DynamoDB incident record created
6. **Reporting**: Bedrock generates incident summary for compliance audit
7. **Resolution**: Manual review + Config rule verification

### Incident Severity Levels

| Level | Criteria | Response Time | Example |
|-------|----------|--------------|---------|
| CRITICAL | Active exploitation, data breach | < 15 minutes | Compromised meter sending grid isolation commands |
| HIGH | Potential breach, policy violation | < 1 hour | Unauthorized S3 access attempt |
| MEDIUM | Suspicious activity, anomalous behavior | < 4 hours | Unusual IoT connection pattern |
| LOW | Informational finding | < 24 hours | Config rule non-compliance |

---

*Security Document v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
