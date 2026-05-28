# GridForge — Example Interactions

> Complete example interactions showing expected LLM outputs for various grid deployment scenarios

---

## Example 1: National Utility Deployment (Ghana)

**User Input:**
```
Deploy grid monitoring for Volta River Authority in Ghana with 8,000 meters
```

**Expected LLM Output:**

### Architecture Overview

The system deploys a full smart grid monitoring pipeline for VRA (Volta River Authority) with the following architecture:

- **IoT Core Thing Group**: `vra-ghana-meters` with 8,000 device registrations
- **Kinesis**: 2 shards on-demand (sufficient for 800K messages/day at 8K meters)
- **Timestream**: Memory store 16GB (24h retention), Magnetic store 160GB (365d retention)
- **Greengrass**: 400 edge gateways at VRA substations (2 meters per gateway avg)
- **QuickSight**: "VRA Grid Operations Center" dashboard

### Terraform Configuration Snippet

```hcl
module "networking" {
  source       = "./modules/networking"
  vpc_cidr     = "10.0.0.0/16"
  region       = "af-south-1"
  utility_name = "VRA-Ghana"
  azs          = ["af-south-1a", "af-south-1b", "af-south-1c"]
}

module "iot_ingestion" {
  source               = "./modules/iot-ingestion"
  utility_name         = "VRA-Ghana"
  meter_count          = 8000
  thing_group_name     = "vra-ghana-meters"
  enable_greengrass    = true
  greengrass_gateways  = 400
  enable_device_defender = true
}

module "data_pipeline" {
  source                       = "./modules/data-pipeline"
  utility_name                 = "VRA-Ghana"
  meter_count                  = 8000
  kinesis_mode                 = "on_demand"
  timestream_memory_retention  = 24
  timestream_magnetic_retention = 365
}

module "analytics_ml" {
  source            = "./modules/analytics-ml"
  utility_name      = "VRA-Ghana"
  meter_count       = 8000
  enable_sagemaker  = true
  enable_bedrock    = true
}

module "security_compliance" {
  source       = "./modules/security-compliance"
  utility_name = "VRA-Ghana"
  enable_nerc_cip = true
}
```

### Cost Estimate

| Service | Monthly Cost (8K meters) |
|---------|-------------------------|
| IoT Core | $120 |
| Greengrass | $40 |
| Kinesis | $45 |
| Timestream | $170 |
| Lambda | $25 |
| Bedrock | $70 |
| SageMaker | $80 |
| QuickSight | $40 |
| Security | $55 |
| **Total** | **~$645/month** |

### PURC Compliance Notes

The deployment includes Ghana-specific PURC (Public Utilities Regulatory Commission) compliance:
- Data residency: All data stored in af-south-1 (within Africa)
- Audit trail: CloudTrail with 7-year retention (PURC requirement)
- Revenue protection: Device Defender detects meter tampering
- Consumer data privacy: KMS encryption + VPC isolation

### Validation Commands

```bash
# Verify VRA deployment
aws iot describe-thing-group --thing-group-name vra-ghana-meters
aws timestream-write describe-database --database-name grid-telemetry
aws lambda invoke --function-name gridforge-anomaly-detector response.json
```

---

## Example 2: City-Level Predictive Maintenance (Lagos)

**User Input:**
```
Add predictive maintenance for transformers at 12 substations in Lagos
```

**Expected LLM Output:**

### Focused Architecture

This deployment focuses on transformer health monitoring at 12 Eko Electric substations in Lagos:

- **Greengrass**: 12 edge gateways (1 per substation)
- **Timestream**: Dedicated table `transformer-health` with schema:
  - `oil_temperature` (°C): Continuous monitoring
  - `dissolved_gas_h2` (ppm): Hydrogen dissolved gas analysis
  - `dissolved_gas_ch4` (ppm): Methane dissolved gas analysis
  - `dissolved_gas_c2h2` (ppm): Acetylene (key indicator of arcing)
  - `load_tap_changer_position`: Current tap position
  - `bushing_current` (mA): Bushing insulation health
  - `winding_temperature` (°C): Hot spot temperature

- **SageMaker**: XGBoost model trained on IEEE C57.104 transformer failure data
- **Bedrock Agent**: "Transformer Analyst" with knowledge base of IEC 60076 standards

### Terraform Configuration

```hcl
module "analytics_ml" {
  source              = "./modules/analytics-ml"
  utility_name        = "Eko-Electric-Lagos"
  meter_count         = 3000
  enable_sagemaker    = true
  sagemaker_model     = "xgboost-transformer-health-v1"
  sagemaker_features  = [
    "oil_temperature",
    "dissolved_gas_h2",
    "dissolved_gas_ch4",
    "dissolved_gas_c2h2",
    "load_tap_changer_position",
    "bushing_current",
    "winding_temperature"
  ]
  enable_bedrock      = true
  bedrock_knowledge_base = "iec-60076-transformer-standards"
  greengrass_gateways = 12
}
```

### Step Functions Workflow

The transformer response orchestrator follows this flow:

1. **Receive**: Anomaly event from EventBridge (e.g., oil temperature > 85°C)
2. **Classify**: Severity assessment (LOW: 75-85°C, MEDIUM: 85-95°C, HIGH: 95-110°C, CRITICAL: > 110°C)
3. **If CRITICAL**: Send IoT command to reduce transformer load via load tap changer
4. **Notify**: SNS to maintenance dispatch team + SES email to utility management
5. **Log**: DynamoDB incident record with full telemetry snapshot
6. **Report**: Bedrock generates natural language incident report referencing IEC 60076 thresholds

### Cost Estimate: ~$320/month

---

## Example 3: Rural Cooperative Budget Deployment

**User Input:**
```
I need a cost-optimized deployment for a rural cooperative with 500 meters and $200/month budget
```

**Expected LLM Output:**

### Minimal Architecture

For budget-constrained deployments, we eliminate non-essential services:

**Included:**
- IoT Core: 500 device connections, ~50K messages/day
- Timestream: Memory 4GB (12h retention), Magnetic 10GB (90d retention — reduced from 365d)
- Lambda: Anomaly detector with rule-based thresholds only (no SageMaker ML endpoint)
- QuickSight: 1 reader dashboard

**Excluded (to save costs):**
- ~~Kinesis~~ — Direct IoT Rule → Timestream (no intermediate stream)
- ~~Firehose~~ — Not needed without Kinesis
- ~~SageMaker~~ — Rule-based anomaly detection instead of ML
- ~~Bedrock~~ — Removed for cost savings
- ~~Greengrass~~ — Removed; meters connect directly to IoT Core
- ~~Device Defender~~ — Removed for cost savings
- **Single AZ deployment** — Acceptable for rural non-critical infrastructure

### Terraform Configuration

```hcl
module "iot_ingestion" {
  source               = "./modules/iot-ingestion"
  utility_name         = "Rural-Cooperative"
  meter_count          = 500
  enable_greengrass    = false    # Save $50/month
  enable_device_defender = false  # Save $10/month
}

module "data_pipeline" {
  source                        = "./modules/data-pipeline"
  utility_name                  = "Rural-Cooperative"
  meter_count                   = 500
  enable_kinesis                = false  # Save $50/month
  enable_firehose               = false  # Save $30/month
  timestream_memory_retention   = 12     # Save ~$8/month
  timestream_magnetic_retention = 90     # Save ~$15/month
}

module "analytics_ml" {
  source            = "./modules/analytics-ml"
  utility_name      = "Rural-Cooperative"
  meter_count       = 500
  enable_sagemaker  = false  # Save $100/month
  enable_bedrock    = false  # Save $80/month
  anomaly_mode      = "rule_based"  # No ML, threshold-based only
}

module "security_compliance" {
  source       = "./modules/security-compliance"
  utility_name = "Rural-Cooperative"
  enable_guardduty   = false  # Save $25/month
  enable_security_hub = false # Save $10/month
}
```

### Rule-Based Anomaly Detection

Without SageMaker, the Lambda anomaly detector uses configurable thresholds:

```python
THRESHOLDS = {
    "voltage_low": 180.0,    # Volts - below this is anomalous
    "voltage_high": 260.0,   # Volts - above this is anomalous
    "frequency_deviation": 0.5,  # Hz - deviation from 50Hz
    "power_factor_low": 0.85,    # Below this is anomalous
    "current_spike": 50.0,       # Amps - sudden spike threshold
}
```

### Cost Estimate: ~$180/month (within $200 budget!)

| Service | Cost |
|---------|------|
| IoT Core (500 devices) | $40 |
| Timestream (reduced retention) | $45 |
| Lambda (rule-based anomaly) | $5 |
| QuickSight (1 reader) | $5 |
| S3 (minimal storage) | $5 |
| CloudWatch (basic monitoring) | $15 |
| KMS + Config (basic security) | $15 |
| SNS (notifications) | $2 |
| **Total** | **~$180/month** |

### Growth Path

As the cooperative scales, modules can be added incrementally:
1. **500 → 1,000 meters**: Add Kinesis for stream processing (+$50/month)
2. **1,000 → 5,000 meters**: Add SageMaker for ML anomaly detection (+$100/month)
3. **5,000 → 10,000 meters**: Add Greengrass for edge processing (+$50/month)
4. **10,000+ meters**: Add Bedrock for AI analysis (+$80/month)

---

## Example 4: Multi-Utility Regional Hub

**User Input:**
```
Create a shared infrastructure hub serving 3 utilities in East Africa: Kenya Power (50K meters), TANESCO Tanzania (20K meters), and REG Rwanda (5K meters)
```

**Expected LLM Output:**

### Multi-Tenant Architecture

The hub uses AWS Organizations for multi-tenant isolation:

- **AWS Organizations**: 3 OUs (Kenya Power, TANESCO, REG-Rwanda)
- **Shared VPC**: Transit Gateway connecting 3 utility VPCs
- **Per-utility Timestream**: Separate databases per utility (data isolation)
- **Centralized security**: Single GuardDuty + Security Hub account
- **Shared SageMaker**: Multi-tenant inference endpoint (cost sharing)

### Cost Estimate: ~$2,800/month total

| Utility | Meters | Monthly Cost |
|---------|--------|-------------|
| Kenya Power | 50,000 | $1,800 |
| TANESCO | 20,000 | $700 |
| REG Rwanda | 5,000 | $300 |
| **Total** | **75,000** | **~$2,800** |

---

## Example 5: Disaster Recovery Configuration

**User Input:**
```
Add disaster recovery for our GridForge deployment with RPO of 1 hour and RTO of 4 hours
```

**Expected LLM Output:**

### DR Architecture

- **DR Region**: eu-west-1 (Ireland) — closest region with full service availability
- **S3 CRR**: Cross-region replication for data lake (continuous)
- **Timestream**: Magnetic store backup to S3 (hourly AWS Backup jobs)
- **Lambda**: Same functions deployed in eu-west-1 (inactive, ready to activate)
- **Route 53**: Health checks with automated failover
- **Step Functions**: DR activation workflow

### Additional Cost: ~$220/month

| Component | Monthly Cost |
|-----------|-------------|
| S3 CRR (replication) | $20 |
| AWS Backup (Timestream) | $50 |
| Lambda (standby, inactive) | $5 |
| Route 53 health checks | $15 |
| CloudWatch (cross-region) | $30 |
| VPN peering (af-south-1 ↔ eu-west-1) | $50 |
| Additional KMS keys (eu-west-1) | $4 |
| Data transfer (inter-region) | $46 |
| **Total** | **~$220/month** |

---

## Example 6: Regulatory Compliance Audit Package

**User Input:**
```
Generate a complete NERC CIP compliance audit package for our smart grid deployment
```

**Expected LLM Output:**

### Audit Package Contents

1. **Config Rule Evaluation Report**: Automated compliance status for all 6 NERC CIP-mapped rules
2. **IAM Access Analyzer Findings**: Unused permissions, cross-account access, public access
3. **CloudTrail Log Integrity Verification**: SHA-256 digest validation for last 90 days
4. **KMS Key Rotation Audit**: Confirmation of 90-day rotation on all 4 CMKs
5. **Security Hub NERC CIP Compliance Score**: Overall compliance percentage
6. **GuardDuty Findings Summary**: Threat detection events for audit period
7. **VPC Flow Log Analysis**: Network traffic patterns and anomalies
8. **Automated Evidence Collection Lambda**: Collects all evidence into S3 audit bucket

### Estimated Audit Preparation

| Task | Manual Time | GridForge Automated Time |
|------|------------|------------------------|
| Evidence collection | 2 weeks | 2 hours |
| Compliance mapping | 1 week | 30 minutes |
| Finding remediation | 1 week | 4 hours |
| Report generation | 3 days | 1 hour |
| **Total** | **~4 weeks** | **~8 hours** |

---

*Examples Document v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
