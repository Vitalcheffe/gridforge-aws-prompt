# GridForge — Judge Evaluation Guide

> Comprehensive guide for AWS Prompt the Planet Challenge judges to evaluate GridForge

---

## What GridForge Is

GridForge is a **production-grade system prompt** that, when given to any LLM (Claude, GPT-4, Amazon Bedrock), generates **complete AWS smart grid infrastructure** for Sub-Saharan African utility companies. It is NOT an application — it is a **prompt engineering artifact** that produces deployable infrastructure-as-code.

**The core deliverable is the prompt file**: [`GridForge_PROMPT.txt`](../GridForge_PROMPT.txt)

---

## Evaluation Paths

### Path A: Quick Evaluation (5 minutes)

1. Open [`GridForge_PROMPT.txt`](../GridForge_PROMPT.txt)
2. Copy the entire prompt
3. Paste into [Amazon Bedrock Playground](https://console.aws.amazon.com/bedrock/) or [Claude](https://claude.ai/)
4. Input: `"Deploy grid monitoring for 5,000 meters in Accra, Ghana"`
5. Verify the output includes:
   - [ ] Architecture overview with Mermaid diagram
   - [ ] Complete Terraform modules (8 modules)
   - [ ] NERC CIP security controls mapping
   - [ ] Cost estimate specific to af-south-1
   - [ ] Validation commands
   - [ ] Deployment guide with step-by-step instructions
   - [ ] Example interactions

### Path B: Standard Evaluation (30 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/Vitalcheffe/gridforge-aws-prompt.git
cd gridforge-aws-prompt

# 2. Validate Terraform syntax
cd infra/terraform
terraform init -backend=false
terraform validate    # Should return "Success! The configuration is valid."

# 3. Check module structure (8 modules expected)
ls modules/*/main.tf

# 4. Review the prompt
cat GridForge_PROMPT.txt | wc -l    # 500+ lines expected

# 5. Generate synthetic test data
python3 scripts/generate-test-data.py --meters 100 --count 10

# 6. Estimate costs
./scripts/cost-estimate.sh 10000 af-south-1

# 7. Run validation script
./scripts/validate.sh

# 8. Review documentation
cat ARCHITECTURE.md    # Detailed architecture documentation
cat SECURITY.md        # NERC CIP compliance mapping
cat COST_ANALYSIS.md   # 3-year TCO comparison
cat WELL_ARCHITECTED.md # AWS 5-pillar alignment
```

### Path C: Full Deployment Evaluation (2 hours)

Requires an AWS account with af-south-1 access and ~$5 budget:

```bash
# 1. Full deployment
./scripts/deploy.sh dev "JudgeTest" 100

# 2. Run smoke test
./scripts/smoke-test.sh

# 3. Verify each component
aws iot describe-thing-group --thing-group-name gridforge-meters
aws timestream-write describe-database --database-name grid-telemetry
aws lambda get-function --function-name gridforge-anomaly-detector
aws stepfunctions describe-state-machine --state-machine-arn <arn-from-outputs>

# 4. Clean up
cd infra/terraform && terraform destroy -auto-approve
```

---

## Evaluation Criteria Mapping

### 1. Robust, Deterministic, and Clear Prompt

| Criteria | GridForge Evidence | Where to Find |
|----------|-------------------|---------------|
| Deterministic output | CO-STAR framework ensures consistent structure | `GridForge_PROMPT.txt` [CONTEXT] through [RESPONSE FORMAT] |
| Clear sections | 6 explicitly defined output sections with numbered steps | `GridForge_PROMPT.txt` [RESPONSE FORMAT] |
| No ambiguity | Specific thresholds, service names, and regional references | All sections reference af-south-1 pricing and limits |
| Reusable | Same prompt works for any utility scale (500 to 50,000 meters) | `EXAMPLES.md` shows 6 different scenarios |

### 2. Prompts That Simplify

| Criteria | GridForge Evidence | Where to Find |
|----------|-------------------|---------------|
| Complex → Simple | Single prompt replaces weeks of architecture work | User input: 1 sentence → Output: 8 Terraform modules + security + costs |
| No configuration drift | Generated IaC is always consistent | Terraform modules follow strict naming and structure |
| Production-ready | NERC CIP compliance, least-privilege IAM, KMS encryption | `SECURITY.md`, `infra/terraform/security-compliance/` |

### 3. Solutions for Enterprise Frictions

| Friction | GridForge Solution | Where to Find |
|----------|-------------------|---------------|
| Cost optimization | Budget controls, Graviton/ARM, Spot, Intelligent-Tiering | `COST_ANALYSIS.md`, `infra/terraform/cost-optimization/` |
| IAM security baselines | 12 least-privilege IAM roles with policy documents | `SECURITY.md`, `infra/terraform/security-compliance/iam-policies/` |
| Serverless routing | Lambda + Step Functions + EventBridge orchestration | `infra/terraform/analytics-ml/`, `infra/lambda/` |
| Heavy data handling | Kinesis + Firehose + Timestream + S3 data lake | `ARCHITECTURE.md`, `infra/terraform/data-pipeline/` |
| Edge computing | Greengrass edge anomaly detection with TensorFlow Lite | `docker/greengrass-edge/` |

### 4. Clear & Actionable Formats

| Format | GridForge Output | Where to Find |
|--------|-----------------|---------------|
| Step-by-step instructions | 10-step deployment guide | `DEPLOYMENT.md` |
| IaC snippets (Terraform) | 8 complete modules with HCL | `infra/terraform/` |
| Examples | 6 scenario-based examples with full outputs | `EXAMPLES.md` |
| Troubleshooting | Common issues and solutions | `docs/TROUBLESHOOTING.md` |

---

## Key Differentiators to Evaluate

### 1. Domain Specificity
GridForge is the **only submission** targeting smart grid / energy infrastructure for emerging markets. Most submissions target generic enterprise patterns (cost optimization, CI/CD, security baselines). GridForge addresses a **$47B+ market** with a specific, underserved use case.

### 2. Regional Optimization
GridForge is optimized for **af-south-1** (Cape Town) — the only AWS region in Sub-Saharan Africa. This includes:
- Regional pricing calculations
- Service availability checks (not all services available in af-south-1)
- Latency analysis for African utility networks
- Compliance with African regulatory bodies (PURC, NERC Nigeria, EWSA)

### 3. Production-Grade Lambda Functions
GridForge includes **4 complete Lambda functions** in Python:
- `anomaly-detector` — 381 lines, IEEE 1159 classification, SageMaker integration
- `grid-event-processor` — 229 lines, Step Functions event handling
- `data-attestation` — Cryptographic hash verification, schema validation, NERC CIP-010 audit trail
- `cost-monitor` — Cost Explorer integration, budget alerts, right-sizing recommendations

### 4. Edge Computing
The `docker/greengrass-edge/` directory includes a complete Greengrass edge gateway with:
- TensorFlow Lite model for voltage sag detection
- IEEE 1159 voltage classification adapted for 230V/50Hz African grids
- Store-and-forward pattern for intermittent connectivity
- Local simulation mode for development

### 5. Comprehensive Validation
Multiple validation paths:
- `validate.sh` — Infrastructure validation without deployment
- `smoke-test.sh` — End-to-end testing after deployment
- `cost-estimate.sh` — Cost estimation for any meter count/region
- `generate-test-data.py` — Synthetic meter data generator with African grid parameters

### 6. AWS Well-Architected Framework
Explicit alignment with all 5 pillars in `WELL_ARCHITECTED.md`:
- Operational Excellence
- Security
- Reliability
- Performance Efficiency
- Cost Optimization

---

## Scoring Rubric Suggestion

| Category | Weight | GridForge Strengths |
|----------|--------|---------------------|
| Prompt Quality & Clarity | 25% | CO-STAR framework, 6 structured output sections, deterministic format |
| AWS Service Coverage | 20% | 15+ services spanning IoT, ML, Edge, Serverless, Analytics, Security |
| Production Readiness | 20% | 8 Terraform modules, 4 Lambda functions, NERC CIP compliance, IaC validation |
| Real-World Impact | 15% | $47B+ market, 95% cost reduction vs SCADA, addresses energy crisis |
| Innovation & Uniqueness | 10% | Only energy/grid submission, af-south-1 optimization, edge computing |
| Documentation & Reproducibility | 10% | 10+ documentation files, 5 scripts, validation guide, 6 examples |

---

## File Inventory for Judges

| File | Lines | Purpose |
|------|-------|---------|
| `GridForge_PROMPT.txt` | 500+ | **Core deliverable** — the complete CO-STAR prompt |
| `README.md` | 400+ | Project overview, architecture, cost analysis |
| `EXAMPLES.md` | 500+ | 6+ example interactions with full outputs |
| `ARCHITECTURE.md` | 368 | Detailed architecture with data flow diagrams |
| `SECURITY.md` | 512 | NERC CIP compliance, threat model, IAM roles |
| `COST_ANALYSIS.md` | 291 | 3-year TCO, scaling projections, regional comparison |
| `DEPLOYMENT.md` | 445 | 10-step deployment guide |
| `VALIDATION.md` | 277 | Judge validation guide |
| `WELL_ARCHITECTED.md` | 300+ | AWS 5-pillar alignment |
| `infra/terraform/` (8 modules) | 2500+ | Complete Terraform IaC |
| `infra/lambda/` (4 functions) | 1200+ | Production Python Lambda code |
| `scripts/` (5 scripts) | 700+ | Deployment, validation, testing, cost estimation |
| `docker/greengrass-edge/` | 400+ | Edge gateway Docker image |

**Total: 7,000+ lines across 40+ files**

---

*Judge Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
