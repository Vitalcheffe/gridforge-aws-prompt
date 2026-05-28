# GridForge — DoraHacks BUIDL Form Content

> Pre-written content for the AWS Prompt the Planet Challenge submission form on DoraHacks

---

## BUIDL Name

GridForge — AWS Smart Grid Infrastructure Deployer for Emerging Markets

---

## Vision (256 characters max)

GridForge is a production-grade CO-STAR prompt that generates complete AWS smart grid infrastructure (Terraform IaC, IoT pipeline, ML/AI, security) for Sub-Saharan African utilities — reducing deployment from months to minutes and costs by 95%.

---

## Description & Use Case (960 characters max)

Sub-Saharan Africa loses 25% of generated electricity to T&D losses (3x the global average). GridForge is a production-grade system prompt that generates complete AWS smart grid infrastructure for budget-constrained African utilities. Given to any LLM (Claude, Bedrock, GPT-4), it outputs: (1) Architecture overview with Mermaid diagrams, (2) 8 modular Terraform configurations deployable with `terraform apply`, (3) IoT pipeline for 10K+ meters via IoT Core + Greengrass edge, (4) ML/AI anomaly detection (SageMaker + Bedrock), (5) NERC CIP security baselines (12 IAM roles, KMS, GuardDuty, Security Hub), (6) Cost optimization for af-south-1 (Graviton, Spot, Intelligent-Tiering). Optimized for 230V/50Hz African grids, PURC/NERC/EWSA regulatory compliance, and $200-$3000/month budgets. Includes validation scripts, 4 production Lambda functions, synthetic data generator, and edge anomaly detection Docker image.

---

## Category

AI Agent

---

## AWS Services Used (960 characters max)

IoT Core (10K+ meter MQTT ingestion, Thing Groups, Rules Engine, Device Defender), Greengrass v2 (edge anomaly detection, TensorFlow Lite, store-and-forward), Kinesis Data Streams (on-demand real-time telemetry), Kinesis Firehose (Parquet buffering to S3), Timestream (dual-tier time-series storage, 24h memory/365d magnetic), S3 (Intelligent-Tiering data lake), Glue (schema crawler, data catalog), Athena (SQL queries on data lake), Lambda (4 functions: anomaly-detector, event-processor, data-attestation, cost-monitor — all arm64/Graviton), Step Functions (6-state incident response orchestrator), EventBridge (anomaly event routing), SageMaker (Serverless XGBoost inference for predictive maintenance), Bedrock (Claude 3.5 Sonnet Grid Analyst agent with Knowledge Base), QuickSight (Grid Operations Center dashboard), DynamoDB (incident logging, dedup, cost trends), CloudWatch (metrics, alarms, dashboards), SNS (critical/operational/cost alerts), SES (operator email notifications), IAM (12 least-privilege roles), KMS (4 CMKs with 90-day rotation), Config (6 NERC CIP rules), GuardDuty (S3 + IoT + malware protection), Security Hub (NERC CIP standard), CloudTrail (multi-region audit trail), ACM Private CA (IoT certificate management), WAF (API Gateway protection), VPC (3-tier subnets, 11 VPC endpoints), Transit Gateway (hybrid SCADA connectivity)

---

## Example Output (960 characters max)

Input: "Deploy grid monitoring for 5,000 meters in Accra, Ghana"

Output includes: (1) Mermaid architecture diagram showing Smart Meters → IoT Core → Kinesis → Lambda → Step Functions flow, (2) Component inventory table with 15+ AWS services, af-south-1 costs (~$645/month), and latency estimates, (3) Complete Terraform configuration with 8 modules: networking (VPC 10.0.0.0/16, 9 subnets, 11 VPC endpoints), iot-ingestion (IoT Thing Group, 3 SQL rules, Device Defender, Greengrass edge gateways), data-pipeline (Kinesis on-demand, Firehose→S3 Parquet, Timestream 24h/365d), analytics-ml (Lambda anomaly-detector with IEEE 1159 classification, Step Functions 6-state orchestrator, SageMaker XGBoost, Bedrock Grid Analyst), security-compliance (12 IAM roles, 4 KMS CMKs, 6 Config Rules, GuardDuty, Security Hub NERC CIP), cost-optimization (budget alerts, Graviton, Spot recommendations), (4) PURC compliance mapping, (5) Validation commands, (6) Deployment guide.

---

## Installation Steps (960 characters max)

1. Copy the complete prompt from GridForge_PROMPT.txt in the GitHub repo
2. Paste into any LLM (Claude, Amazon Bedrock, GPT-4)
3. Provide grid parameters: "Deploy grid monitoring for [utility] in [country] with [N] meters"
4. LLM generates complete infrastructure: architecture, Terraform, security, costs, deployment guide

For full validation:
```bash
git clone https://github.com/Vitalcheffe/gridforge-aws-prompt.git
cd gridforge-aws-prompt/infra/terraform
terraform init -backend=false
terraform validate  # Returns "Success!"
cd ../../..
./scripts/cost-estimate.sh 10000 af-south-1
python3 scripts/generate-test-data.py --meters 100 --count 10
```

For deployment:
```bash
./scripts/deploy.sh production "VRA-Ghana" 8000
./scripts/smoke-test.sh
```

---

## Use Case Examples (960 characters max)

1. National Utility (Ghana): VRA deploys 8,000-meter grid monitoring with PURC compliance. Cost: $645/month vs $15,000+ SCADA.
2. Predictive Maintenance (Nigeria): Eko Electric adds transformer failure prediction at 12 Lagos substations using SageMaker XGBoost on IEEE C57.104 data. Cost: $320/month.
3. Rural Cooperative ($200 budget): 500-meter minimal deployment with rule-based detection, no ML. Growth path to SageMaker at 5K meters. Cost: $180/month.
4. Multi-Utility Hub (East Africa): Kenya Power (50K), TANESCO (20K), REG Rwanda (5K) share infrastructure via AWS Organizations + Transit Gateway. Cost: $2,800/month total.
5. Disaster Recovery: Add cross-region DR (af-south-1 → eu-west-1) with RPO 1h / RTO 4h. Additional cost: $220/month.
6. Regulatory Audit: Generate complete NERC CIP compliance package (Config rules, IAM analysis, CloudTrail verification, KMS rotation audit). Preparation time: 4 weeks → 8 hours.

---

## Troubleshooting Tips (960 characters max)

1. af-south-1 not available: Enable Cape Town region in AWS Account Settings → Regions
2. Bedrock access denied: Request Bedrock model access in AWS Console (24-48h approval). Workaround: set enable_bedrock = false for rule-based detection
3. Terraform validate fails: Run terraform init first to download providers. Check terraform.tfvars for type mismatches
4. IoT messages not reaching Lambda: Verify IoT topic rule is active (aws iot get-topic-rule). Check Lambda event source mapping on Kinesis
5. Kinesis iterator age increasing: Lambda processing slower than input rate. Switch Kinesis to on-demand mode or increase Lambda concurrency
6. Budget exceeded: Apply right-sizing — Lambda arm64 (20% savings), SageMaker Serverless (45%), S3 Intelligent-Tiering (30%), disable unused features
7. Certificate errors on meters: Verify ACM Private CA is active. Check certificate rotation hasn't expired. Use aws iot describe-certificate

---

## Links

- **GitHub**: https://github.com/Vitalcheffe/gridforge-aws-prompt
- **DoraHacks BUIDL**: https://dorahacks.io/buidl/44036

---

*Submission Content v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
