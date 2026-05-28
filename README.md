# GridForge — AWS Smart Grid Infrastructure Deployer for Emerging Markets

> **Production-Grade LLM Prompt for Deploying Predictive Grid Intelligence on AWS**
> Submitted to the [AWS Prompt the Planet Challenge](https://dorahacks.io/hackathon/awsprompttheplanet) on DoraHacks
> **BUIDL**: [dorahacks.io/buidl/44036](https://dorahacks.io/buidl/44036)

---

## The Problem

Sub-Saharan Africa loses **25% of generated electricity** to transmission and distribution losses — more than 3x the global average of 8%. This represents billions of dollars in annual economic losses and affects hundreds of thousands of households across the region. Traditional grid monitoring relies on aging SCADA systems that cannot scale, predict failures, or optimize in real-time.

## The Solution

**GridForge** is a production-grade system prompt that, when given to any LLM (Claude, GPT-4, Amazon Bedrock), generates complete AWS smart grid infrastructure including:

- **Terraform IaC** — 8 modular Terraform configurations deployable with a single `terraform apply`
- **IoT Pipeline** — 10,000+ smart meter ingestion via AWS IoT Core + Greengrass edge computing
- **Real-Time Analytics** — Timestream + Kinesis + Lambda anomaly detection + Step Functions orchestration
- **ML/AI Intelligence** — Bedrock Claude 3.5 for grid analysis + SageMaker for predictive maintenance
- **Security Baselines** — NERC CIP compliance with GuardDuty, Security Hub, Config Rules, KMS encryption
- **Cost Optimization** — Graviton/ARM, Spot instances, Intelligent-Tiering — optimized for af-south-1 (Cape Town)
- **Validation Scripts** — Judges can verify the prompt output without deploying resources

## Quick Start

1. Copy the prompt from [`GridForge_PROMPT.txt`](./GridForge_PROMPT.txt)
2. Paste into Claude, Amazon Bedrock, or any LLM
3. Provide your grid parameters: region, meter count, utility name, budget
4. Receive complete Terraform infrastructure + deployment guide + cost analysis

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌───────────────┐
│ Smart Meters │────▶│  AWS IoT Core │────▶│  Kinesis Streams  │────▶│     Lambda     │
│  (10,000+)  │     │  + Greengrass │     │   (on-demand)     │     │  Anomaly Det.  │
└─────────────┘     └──────────────┘     └──────────────────┘     └───────┬───────┘
                           │                      │                        │
                           ▼                      ▼                        ▼
                    ┌──────────────┐     ┌──────────────────┐     ┌───────────────┐
                    │  Timestream   │     │   S3 Data Lake    │     │ Step Functions │
                    │  (telemetry)  │     │   (Parquet/Athena) │     │  (orchestrate) │
                    └──────┬───────┘     └────────┬─────────┘     └───────┬───────┘
                           │                      │                        │
                           ▼                      ▼                        ▼
                    ┌──────────────┐     ┌──────────────────┐     ┌───────────────┐
                    │  QuickSight   │     │  SageMaker +      │     │  SNS + SES     │
                    │  Dashboards   │     │  Bedrock (ML/AI)  │     │  (alerts)      │
                    └──────────────┘     └──────────────────┘     └───────────────┘
```

## CO-STAR Framework

GridForge follows the **CO-STAR** prompt engineering framework (Amazon Bedrock best practice):

| Element | GridForge Implementation |
|---------|------------------------|
| **C**ontext | AWS Solutions Architect for emerging market smart grids |
| **O**bjective | Generate complete AWS infrastructure for 10K+ meter deployments |
| **S**tyle | Technical, precise, authoritative with inline Terraform comments |
| **T**one | Professional, confident, trade-off aware |
| **A**udience | DevOps engineers at utility companies in emerging markets |
| **R**esponse | 6 sections: Architecture, Terraform, Security, Cost, Deployment, Examples |

## Security & Compliance

- **NERC CIP** compliance via AWS Config Rules + Security Hub
- **GuardDuty** with S3 and IoT protection enabled
- **KMS CMKs** with 90-day auto-rotation for all data encryption
- **CloudTrail** multi-region audit trail
- **Least-privilege IAM** — 12 roles, one per module
- **VPC isolation** — Isolated subnets for databases, private for compute

## Cost Estimate (10,000 meters, af-south-1)

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| IoT Core | ~$150 | 10K devices, 1M messages/day |
| Kinesis | ~$50 | 2 shards on-demand |
| Timestream | ~$200 | 365-day retention, 24h memory |
| Lambda | ~$30 | Graviton/ARM, provisioned concurrency |
| Step Functions | ~$20 | ~10K state transitions/day |
| SageMaker | ~$100 | Serverless inference |
| Bedrock | ~$80 | Claude 3.5 Sonnet queries |
| QuickSight | ~$40 | 5 readers, 1 author |
| S3 + Glue | ~$50 | Intelligent-Tiering |
| CloudWatch | ~$30 | Logs + Metrics + Alarms |
| Security (GuardDuty, Config, etc.) | ~$50 | Continuous monitoring |
| **Total** | **~$800/month** | **vs $15,000+ on-premise SCADA** |

## Why GridForge Stands Out

1. **Unique Domain**: Only energy/utility-specific prompt in the competition
2. **AWS Strategic Alignment**: Africa is AWS's expansion priority (af-south-1)
3. **Prompt Library Gap**: AWS Startups Prompt Library has zero energy/utility prompts
4. **Production-Ready**: Complete Terraform modules + validation scripts + cost analysis
5. **Real Impact**: $47B+ addressable market in emerging economies

## Validation

```bash
# Validate Terraform syntax
terraform validate

# Check all modules are present
ls -la modules/*/main.tf

# Verify IAM least privilege
terraform plan -target=module.security-compliance

# Dry-run cost estimation
infracost breakdown --path=. --show-skipped
```

## Files

- [`GridForge_PROMPT.txt`](./GridForge_PROMPT.txt) — The complete copy-paste ready prompt
- [`EXAMPLES.md`](./EXAMPLES.md) — Example interactions with the prompt
- [`validate.sh`](./validate.sh) — Validation script for generated Terraform

## License

MIT License — Built by HarchCorp S.A. for the AWS Prompt the Planet Challenge 2026.

---

**Author**: Amine / @Vitalcheffe | **Organization**: HarchCorp S.A. | **Event**: AWS Prompt the Planet Challenge | DoraHacks 2026
