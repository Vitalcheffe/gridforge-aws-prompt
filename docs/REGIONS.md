# GridForge — Regional Availability Guide

> AWS service availability and pricing across African and global regions

---

## Primary Region: af-south-1 (Cape Town)

**af-south-1** is the only AWS region physically located in Sub-Saharan Africa. This is the default region for all GridForge deployments.

### Service Availability

| AWS Service | Available in af-south-1 | Notes |
|-------------|------------------------|-------|
| IoT Core | Yes | Full MQTT support |
| IoT Greengrass | Yes | V2 supported |
| IoT Device Defender | Yes | Full audit and detection |
| Kinesis Data Streams | Yes | On-demand mode supported |
| Kinesis Data Firehose | Yes | All destinations |
| Timestream | Yes | Write and Query |
| S3 | Yes | All storage classes |
| Glue | Yes | Crawlers and ETL |
| Athena | Yes | Standard and federated |
| Lambda | Yes | arm64/Graviton supported |
| Step Functions | Yes | Express and Standard |
| EventBridge | Yes | All event buses |
| DynamoDB | Yes | On-demand and provisioned |
| SageMaker | Yes | Serverless inference supported |
| Bedrock | Yes | Claude 3.5 Sonnet available |
| QuickSight | Yes | Standard and Enterprise |
| CloudWatch | Yes | Logs, Metrics, Alarms, Dashboards |
| SNS | Yes | All protocols |
| SES | Yes | Email sending |
| IAM | Yes | All features |
| KMS | Yes | Custom key stores |
| Config | Yes | All managed rules |
| GuardDuty | Yes | S3, IoT, Malware protection |
| Security Hub | Yes | All standards |
| CloudTrail | Yes | All trails |
| WAF | Yes | Regional and CloudFront |
| VPC | Yes | All features |
| Transit Gateway | Yes | Inter-region peering |
| Organizations | Yes | All features |
| Cost Explorer | Yes (us-east-1 API) | Data available for af-south-1 |

### af-south-1 Pricing Premium

af-south-1 pricing is typically **5-15% higher** than us-east-1 due to infrastructure costs. Key differences:

| Service | us-east-1 | af-south-1 | Premium |
|---------|-----------|-----------|---------|
| IoT Core (per million messages) | $1.00 | $1.15 | +15% |
| Kinesis (per shard hour) | $0.015 | $0.018 | +20% |
| Timestream (per GB memory write) | $0.036 | $0.042 | +17% |
| Lambda (per GB-second) | $0.0000166667 | $0.000019 | +14% |
| S3 Standard (per GB first 50TB) | $0.023 | $0.0265 | +15% |
| SageMaker (ml.c5.xlarge per hour) | $0.204 | $0.24 | +18% |

**Optimization:** Use Graviton/ARM instances and Spot capacity to offset the regional premium.

---

## Alternative Regions for African Utilities

### eu-west-1 (Ireland)

**Best for:** West African utilities (Nigeria, Ghana, Senegal)

| Metric | Value |
|--------|-------|
| Latency from Lagos | ~120ms |
| Latency from Accra | ~130ms |
| Service availability | Full |
| Pricing | Lower than af-south-1 |
| Data residency | EU (GDPR applies) |

**Use when:**
- Utility has regulatory requirements for EU data residency
- Need access to services not yet in af-south-1
- Cost is a primary concern and latency is acceptable

### eu-central-1 (Frankfurt)

**Best for:** East African utilities (Kenya, Tanzania, Rwanda)

| Metric | Value |
|--------|-------|
| Latency from Nairobi | ~140ms |
| Latency from Dar es Salaam | ~160ms |
| Service availability | Full |
| Pricing | Similar to eu-west-1 |

### me-south-1 (Bahrain)

**Best for:** North and East African utilities (Egypt, Sudan, Ethiopia)

| Metric | Value |
|--------|-------|
| Latency from Cairo | ~80ms |
| Latency from Addis Ababa | ~100ms |
| Service availability | Most services |
| Pricing | Moderate |

---

## Latency Comparison

Latency from major African cities to AWS regions (average, TCP handshake):

| City | af-south-1 | eu-west-1 | eu-central-1 | me-south-1 |
|------|-----------|-----------|-------------|-----------|
| **Johannesburg** | **10ms** | 180ms | 200ms | 250ms |
| **Lagos** | 200ms | **120ms** | 140ms | 160ms |
| **Accra** | 210ms | **130ms** | 150ms | 170ms |
| **Nairobi** | 180ms | 140ms | **140ms** | 100ms |
| **Cairo** | 220ms | 100ms | 110ms | **80ms** |
| **Kinshasa** | **80ms** | 160ms | 170ms | 200ms |
| **Addis Ababa** | 200ms | 140ms | 150ms | **100ms** |
| **Dar es Salaam** | 190ms | 160ms | **160ms** | 120ms |

**Recommendation:** Use af-south-1 for Southern African utilities. Consider eu-west-1 for West African utilities if sub-200ms latency is critical.

---

## Multi-Region DR Architecture

For critical infrastructure requiring disaster recovery:

| Primary Region | DR Region | Replication | RPO | RTO | Additional Cost |
|---------------|-----------|-------------|-----|-----|----------------|
| af-south-1 | eu-west-1 | S3 CRR + AWS Backup | 1 hour | 4 hours | +$220/month |
| af-south-1 | eu-central-1 | S3 CRR + AWS Backup | 1 hour | 4 hours | +$240/month |

### DR Considerations for African Utilities

1. **Data sovereignty**: Some African regulators require data to remain on the continent. af-south-1 → af-south-1 same-region DR may be required.
2. **Internet connectivity**: Sub-Saharan Africa has variable international bandwidth. Consider keeping DR within the same region.
3. **Cost sensitivity**: DR adds ~25-30% to monthly costs. Only recommend for Tier 1 critical infrastructure.

---

## Deploying to Different Regions

To deploy GridForge to a region other than af-south-1, update `terraform.tfvars`:

```hcl
# Example: Deploy to eu-west-1 for a Nigerian utility
region          = "eu-west-1"
utility_name    = "Eko-Electric-Nigeria"
meter_count     = 20000
vpc_cidr        = "10.0.0.0/16"
environment     = "production"

# Note: Pricing estimates will differ by region
# Run ./scripts/cost-estimate.sh <meter_count> <region> for accurate costs
```

**Important considerations:**
1. Bedrock availability varies by region — verify Claude 3.5 Sonnet access
2. Adjust Timestream retention policies based on regional pricing
3. Some VPC endpoint services have different names per region
4. Update security group rules for any region-specific IP ranges

---

*Regional Availability Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
