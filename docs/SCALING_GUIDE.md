# GridForge — Scaling Guide

> How to scale GridForge from 500 to 500,000 smart meters

---

## Scaling Tiers

GridForge is designed to scale across five tiers, from rural cooperatives to continental utility operators:

| Tier | Meters | Monthly Budget | Architecture |
|------|--------|---------------|-------------|
| **Micro** | 100 – 500 | $50 – $200 | IoT Core → Timestream → Lambda (rule-based) → QuickSight |
| **Small** | 500 – 5,000 | $200 – $500 | + Kinesis + S3 Data Lake + CloudWatch Alarms |
| **Medium** | 5,000 – 50,000 | $500 – $3,000 | + Greengrass Edge + SageMaker ML + Bedrock AI + Step Functions |
| **Large** | 50,000 – 200,000 | $3,000 – $10,000 | Multi-AZ + Reserved Capacity + Kinesis on-demand scaling |
| **Continental** | 200,000+ | $10,000+ | Multi-region + Transit Gateway + Organizations + Control Tower |

---

## Service-by-Service Scaling

### AWS IoT Core

| Meter Count | Recommended Config | Estimated Monthly Cost |
|-------------|-------------------|----------------------|
| 500 | 1 Thing Group, 50K msg/day | $40 |
| 5,000 | 1 Thing Group, 500K msg/day | $120 |
| 50,000 | 5 Thing Groups (by region), 5M msg/day | $600 |
| 200,000+ | 10+ Thing Groups, 20M msg/day, Fleet Indexing | $2,000+ |

**Scaling notes:**
- IoT Core supports millions of connected devices per account
- Use Thing Groups to organize meters by region/utility
- Enable Fleet Indexing for device search at scale (> 10K devices)
- Use Device Defender at scale for automated security auditing

### Amazon Kinesis

| Meter Count | Shards | Mode | Estimated Monthly Cost |
|-------------|--------|------|----------------------|
| 500 | N/A (skip Kinesis) | — | $0 |
| 5,000 | 2 | On-demand | $50 |
| 50,000 | 10 | On-demand | $250 |
| 200,000+ | 50+ | On-demand | $1,000+ |

**Scaling notes:**
- On-demand mode auto-scales to handle variable telemetry volume
- Each shard supports 1MB/s input, 2MB/s output
- For 10K meters at 1 msg/5s: ~33 msg/s ≈ 33KB/s → 1 shard sufficient
- Always use on-demand mode for African utilities (variable load patterns)

### Amazon Timestream

| Meter Count | Memory Store | Magnetic Store | Retention | Monthly Cost |
|-------------|-------------|----------------|-----------|-------------|
| 500 | 4 GB (12h) | 10 GB (90d) | 12h / 90d | $45 |
| 5,000 | 16 GB (24h) | 80 GB (365d) | 24h / 365d | $200 |
| 50,000 | 80 GB (24h) | 800 GB (365d) | 24h / 365d | $1,500 |
| 200,000+ | 320 GB (24h) | 3.2 TB (365d) | 24h / 365d | $5,000+ |

**Scaling notes:**
- Memory store is expensive but fast — minimize retention (12-24h)
- Magnetic store is cheap for long-term storage
- Use query result caching for dashboard queries
- Partition by date/region for optimal query performance

### AWS Lambda

| Meter Count | Functions | Concurrency | Architecture | Monthly Cost |
|-------------|-----------|-------------|-------------|-------------|
| 500 | 2 (rule-based) | 5 reserved | arm64 | $5 |
| 5,000 | 4 (full suite) | 10 reserved | arm64 | $30 |
| 50,000 | 4 (full suite) | 50 provisioned | arm64 | $200 |
| 200,000+ | 4 (full suite) | 200 provisioned | arm64 | $600+ |

**Scaling notes:**
- Always use arm64 (Graviton) for 20% better price-performance
- Use provisioned concurrency only for production-critical functions
- Rule-based anomaly detection scales better than ML at small scale
- Use Lambda Layers for shared code (reduces cold start)

### Amazon SageMaker

| Meter Count | Endpoint Type | Instance | Monthly Cost |
|-------------|--------------|----------|-------------|
| 500 | None (rule-based) | — | $0 |
| 5,000 | Serverless | — | $100 |
| 50,000 | Real-time | ml.c5.xlarge | $500 |
| 200,000+ | Real-time + Async | ml.c5.2xlarge | $1,500+ |

**Scaling notes:**
- Serverless inference is ideal for bursty grid anomaly patterns
- Real-time endpoints are needed for continuous high-volume inference
- Use multi-model endpoints for cost sharing across utilities
- Batch transform for monthly grid health assessments

### Amazon Bedrock

| Meter Count | Usage Pattern | Monthly Cost |
|-------------|--------------|-------------|
| 500 | Disabled | $0 |
| 5,000 | Ad-hoc operator queries (50/day) | $80 |
| 50,000 | Regular operator queries (500/day) | $400 |
| 200,000+ | Continuous analysis + automated reporting | $1,500+ |

**Scaling notes:**
- Bedrock charges per token — monitor usage with cost allocation tags
- Use Haiku for routine queries, Sonnet for complex analysis
- Cache knowledge base queries to reduce Bedrock invocations
- Set up budget alerts for Bedrock spending

---

## Multi-Region Architecture (50,000+ meters)

For continental-scale deployments, use a multi-region architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Organizations                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ OU: West     │  │ OU: East     │  │ OU: Southern │      │
│  │ Africa       │  │ Africa       │  │ Africa       │      │
│  │ (eu-west-1)  │  │ (af-south-1) │  │ (af-south-1) │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
│                   ┌────────▼────────┐                        │
│                   │ Transit Gateway  │                        │
│                   │   Hub (shared)   │                        │
│                   └────────┬────────┘                        │
│                            │                                 │
│              ┌─────────────┼─────────────┐                   │
│              ▼             ▼             ▼                   │
│        Centralized   Shared SageMaker  Centralized           │
│        GuardDuty     Multi-Model      Security Hub           │
│        + CloudTrail  Endpoint         + Config               │
└─────────────────────────────────────────────────────────────┘
```

### Regional Deployment Strategy

| Region | Coverage | Utilities | Estimated Meters |
|--------|----------|-----------|-----------------|
| af-south-1 | Southern Africa | South Africa, Namibia, Botswana, Mozambique | 200,000+ |
| eu-west-1 | West Africa | Nigeria, Ghana, Senegal, Cote d'Ivoire | 150,000+ |
| eu-central-1 | East Africa | Kenya, Tanzania, Rwanda, Ethiopia | 100,000+ |

---

## Cost Projections by Scale

| Scale | Meters | Year 1 (AWS) | Year 1 (SCADA) | Savings | Savings % |
|-------|--------|-------------|----------------|---------|-----------|
| Micro | 500 | $2,160 | $180,000 | $177,840 | 99% |
| Small | 5,000 | $9,600 | $180,000 | $170,400 | 95% |
| Medium | 50,000 | $36,000 | $540,000 | $504,000 | 93% |
| Large | 200,000 | $120,000 | $1,800,000 | $1,680,000 | 93% |
| Continental | 500,000+ | $300,000 | $4,500,000 | $4,200,000 | 93% |

**Note:** SCADA costs include hardware, licensing, maintenance, and personnel. AWS costs include Reserved Capacity and Savings Plans.

---

## Performance Targets by Scale

| Metric | Micro | Small | Medium | Large | Continental |
|--------|-------|-------|--------|-------|-------------|
| Ingestion Latency (p99) | < 500ms | < 500ms | < 1s | < 2s | < 5s |
| Anomaly Detection (p99) | < 3s | < 3s | < 5s | < 5s | < 10s |
| Dashboard Refresh | 30s | 15s | 10s | 10s | 5s |
| Query Latency (p95) | < 5s | < 5s | < 10s | < 15s | < 30s |
| Availability SLA | 99% | 99.5% | 99.9% | 99.95% | 99.99% |

---

## Scaling Checklist

Before scaling from one tier to the next:

- [ ] **50 → 5,000 meters**: Add Kinesis for stream processing, enable S3 data lake
- [ ] **5,000 → 50,000 meters**: Add Greengrass for edge processing, SageMaker for ML, Bedrock for AI
- [ ] **50,000 → 200,000 meters**: Enable Kinesis on-demand, add provisioned Lambda concurrency, Reserved Capacity
- [ ] **200,000+ meters**: Multi-region deployment, Transit Gateway, Organizations, Control Tower

---

*Scaling Guide v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
