# GridForge — Example Interactions

## Example 1: National Utility Deployment

**User Input:**
```
Deploy grid monitoring for Volta River Authority in Ghana with 8,000 meters
```

**Expected LLM Output:**
- Architecture overview with Mermaid diagram for VRA Ghana
- Terraform modules configured for 8,000 meters (2 Kinesis shards, 16GB Timestream memory store)
- IAM roles scoped to VRA Ghana organizational unit
- Cost estimate: ~$680/month (reduced meter count from baseline 10K)
- Deployment guide with Ghana-specific PURC compliance notes
- Validation commands for af-south-1

---

## Example 2: City-Level Predictive Maintenance

**User Input:**
```
Add predictive maintenance for transformers at 12 substations in Lagos
```

**Expected LLM Output:**
- Focused analytics-ml module with SageMaker XGBoost endpoint for transformer failure prediction
- Greengrass deployment to 12 substation edge gateways
- Timestream table for transformer health metrics (oil temperature, dissolved gas analysis, load tap changer position)
- Step Functions workflow for automated transformer isolation on critical prediction
- Bedrock agent for natural language transformer health queries
- Cost estimate: ~$320/month (focused scope)
- NERC compliance mapping for Nigerian NERC standards

---

## Example 3: Rural Cooperative Budget Deployment

**User Input:**
```
I need a cost-optimized deployment for a rural cooperative with 500 meters and $200/month budget
```

**Expected LLM Output:**
- Minimal architecture: IoT Core → Timestream → QuickSight (no Kinesis, no SageMaker)
- Lambda anomaly detector with rule-based thresholds (no ML endpoint to save costs)
- Single AZ deployment (cost savings, acceptable for rural non-critical infrastructure)
- S3 Intelligent-Tiering for all data storage
- Lambda on Graviton/ARM for maximum price-performance
- Budget alarm at $200/month with auto-mitigation
- Cost estimate: ~$180/month (within budget)
- Growth path: modular upgrade plan as cooperative scales
