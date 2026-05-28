# GridForge — API Reference

> Enterprise API documentation for GridForge smart grid infrastructure components

---

## Overview

GridForge exposes several API interfaces for grid operators, maintenance teams, and external systems:

| Interface | Protocol | Purpose |
|-----------|----------|---------|
| IoT Core MQTT | MQTT v5 | Smart meter telemetry ingestion |
| Bedrock Agent | Natural Language | Grid analysis queries |
| Step Functions | HTTP (via API Gateway) | Incident response orchestration |
| Lambda Functions | Direct Invoke / Event Source | Anomaly detection, event processing, attestation, cost monitoring |
| QuickSight | HTTPS | Dashboard visualization |

---

## 1. IoT Core MQTT API

### Topics

| Topic Pattern | Direction | Description |
|---------------|-----------|-------------|
| `gridforge/telemetry/{utility_name}/{meter_id}` | IN | Meter telemetry ingestion |
| `gridforge/anomaly/{substation_id}/{meter_id}` | OUT | Edge anomaly detection results |
| `gridforge/command/{meter_id}` | OUT | Commands to smart meters (load shed, disconnect) |
| `gridforge/status/{substation_id}` | OUT | Substation status updates |

### Telemetry Message Schema (v1.2)

```json
{
  "schema_version": "v1.2",
  "meter_id": "METER-0001",
  "timestamp": 1700000000,
  "voltage": 228.5,
  "current": 32.1,
  "frequency": 50.02,
  "power_factor": 0.93,
  "substation_id": "substation-accra-01",
  "region": "Greater-Accra",
  "utility_name": "VRA-Ghana"
}
```

### Field Specifications

| Field | Type | Range | Unit | Description |
|-------|------|-------|------|-------------|
| `schema_version` | string | "v1.2" | — | Message schema version |
| `meter_id` | string | — | — | Unique meter identifier (format: `METER-XXXX`) |
| `timestamp` | float | > 0 | Unix epoch | UTC timestamp of the reading |
| `voltage` | float | 0 – 400 | Volts | Line-to-neutral voltage (230V nominal) |
| `current` | float | 0 – 500 | Amps | Line current |
| `frequency` | float | 45 – 55 | Hz | Grid frequency (50Hz nominal) |
| `power_factor` | float | -1 – 1 | — | Power factor (1.0 = ideal) |
| `substation_id` | string | — | — | Substation identifier |
| `region` | string | — | — | Geographic region |
| `utility_name` | string | — | — | Utility company name |

### IoT Core Rules Engine SQL

```sql
-- Route all telemetry to Timestream
SELECT * FROM 'gridforge/telemetry/+/+'

-- Filter critical voltage events for immediate Lambda invocation
SELECT meter_id, timestamp, voltage, frequency
FROM 'gridforge/telemetry/+/+'
WHERE voltage < 180 OR voltage > 260 OR ABS(frequency - 50) > 0.5

-- Route to Kinesis for real-time processing
SELECT meter_id, timestamp, voltage, current, frequency, power_factor, substation_id
FROM 'gridforge/telemetry/+/+'
```

---

## 2. Bedrock Agent API — "Grid Analyst"

### Natural Language Queries

The Bedrock Agent "Grid Analyst" accepts natural language queries about grid status, anomalies, and recommendations.

**Example queries:**
- "What is the current voltage status of the Accra region?"
- "Show me all critical anomalies in the last 24 hours"
- "Which substations have the highest T&D losses?"
- "Predict transformer failure risk for substation Lagos-07"

### API Gateway Integration

```bash
# Query the Grid Analyst via API Gateway
curl -X POST https://{api-id}.execute-api.af-south-1.amazonaws.com/prod/grid-analyst \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "query": "What substations reported voltage sags in the last hour?",
    "context": {
      "utility_name": "VRA-Ghana",
      "region": "af-south-1"
    }
  }'
```

### Response Format

```json
{
  "response": "3 substations reported voltage sags in the last hour...",
  "data": {
    "substations": [
      {
        "id": "substation-accra-03",
        "min_voltage": 178.2,
        "duration_minutes": 12,
        "affected_meters": 245,
        "severity": "CRITICAL"
      }
    ]
  },
  "sources": ["timestream:grid-telemetry/meter-readings", "dynamodb:gridforge-incidents"],
  "confidence": 0.94
}
```

---

## 3. Lambda Functions API

### 3.1 Anomaly Detector

**Function Name:** `gridforge-anomaly-detector`

**Event Source:** Kinesis Data Streams

**Input:** Kinesis records containing meter telemetry

**Output:** SNS notifications + EventBridge events + DynamoDB incident records

**Direct Invocation:**

```bash
aws lambda invoke \
  --function-name gridforge-anomaly-detector \
  --cli-binary-input fileb://test-event.json \
  response.json
```

**Test Event:**

```json
{
  "meter_id": "METER-0001",
  "timestamp": 1700000000,
  "voltage": 175.2,
  "current": 45.8,
  "frequency": 49.8,
  "power_factor": 0.82,
  "substation_id": "substation-accra-01"
}
```

**Response:**

```json
{
  "statusCode": 200,
  "body": {
    "anomalies_detected": 2,
    "results": [
      {
        "type": "VOLTAGE_SAG",
        "severity": "CRITICAL",
        "meter_id": "METER-0001",
        "value": 175.2,
        "threshold": 180.0,
        "ieee_class": "SAG_SEVERE",
        "action": "ALERT_OPERATORS"
      },
      {
        "type": "LOW_POWER_FACTOR",
        "severity": "LOW",
        "meter_id": "METER-0001",
        "value": 0.82,
        "threshold": 0.85,
        "action": "LOG_ONLY"
      }
    ],
    "sagemaker_prediction": {
      "failure_probability": 0.78,
      "predicted_failure_hours": 48,
      "model_version": "xgboost-v2.1"
    }
  }
}
```

### 3.2 Grid Event Processor

**Function Name:** `gridforge-grid-event-processor`

**Event Source:** Step Functions

**Input:** Step Functions state machine payload

**Actions:**
- Segment isolation via IoT Core command
- SNS + SES operator notification
- DynamoDB incident logging

### 3.3 Data Attestation

**Function Name:** `gridforge-data-attestation`

**Event Source:** Kinesis Data Streams (parallel consumer)

**Input:** Kinesis records containing meter telemetry

**Output:** DynamoDB attestation records + SNS alerts on invalid data

**Features:**
- SHA-256 content hash verification
- Schema validation (v1.2)
- Timestamp freshness checks
- Duplicate detection
- Out-of-range value detection

### 3.4 Cost Monitor

**Function Name:** `gridforge-cost-monitor`

**Event Source:** EventBridge scheduled rule (daily at 06:00 UTC)

**Output:** SNS/SES budget alerts + DynamoDB cost snapshots

**Direct Invocation:**

```bash
aws lambda invoke \
  --function-name gridforge-cost-monitor \
  --payload '{}' \
  response.json
```

**Response:**

```json
{
  "statusCode": 200,
  "body": {
    "budget_status": {
      "current_spend": 456.78,
      "budget": 800.00,
      "consumption_pct": 57.1,
      "alert_level": "GREEN",
      "projected_monthly": 780.50,
      "per_meter_cost": 0.0457
    },
    "recommendations": [...]
  }
}
```

---

## 4. Step Functions — Grid Response Orchestrator

### State Machine: `gridforge-grid-response-orchestrator`

**Trigger:** EventBridge rule matching anomaly events

**States:**

| State | Type | Timeout | Purpose |
|-------|------|---------|---------|
| ClassifySeverity | Task | 30s | Determine incident severity level |
| SeverityChoice | Choice | — | Route based on severity |
| IsolateGridSegment | Task | 60s | Send IoT command to isolate affected segment |
| NotifyOperators | Task | 30s | SNS + SES notification |
| LogIncident | Task | 30s | DynamoDB incident record |
| GenerateReport | Task | 60s | Bedrock natural language report |

### Execution Input

```json
{
  "anomaly_id": "ANOM-2026-001234",
  "meter_id": "METER-0421",
  "substation_id": "substation-accra-03",
  "anomaly_type": "VOLTAGE_SAG",
  "severity": "CRITICAL",
  "voltage": 168.5,
  "timestamp": 1700000000,
  "utility_name": "VRA-Ghana"
}
```

### Start Execution

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:af-south-1:123456789012:stateMachine:gridforge-grid-response-orchestrator \
  --input file://execution-input.json
```

---

## 5. Timestream Query API

### Common Queries

```sql
-- Average voltage by region (last 24 hours)
SELECT region, AVG(voltage) AS avg_voltage
FROM "grid-telemetry"."meter-readings"
WHERE time > ago(24h)
GROUP BY region
ORDER BY avg_voltage ASC

-- Top 10 meters with lowest voltage (last hour)
SELECT meter_id, substation_id, MIN(voltage) AS min_voltage
FROM "grid-telemetry"."meter-readings"
WHERE time > ago(1h)
GROUP BY meter_id, substation_id
ORDER BY min_voltage ASC
LIMIT 10

-- T&D Loss calculation (generated vs delivered energy)
SELECT
  substation_id,
  SUM(voltage * current * power_factor) / 1000 AS delivered_kwh,
  time_bin(time, 1h) AS hour
FROM "grid-telemetry"."meter-readings"
WHERE time > ago(24h)
GROUP BY substation_id, time_bin(time, 1h)
ORDER BY hour DESC

-- Frequency deviation events (last 7 days)
SELECT meter_id, frequency, time
FROM "grid-telemetry"."meter-readings"
WHERE time > ago(7d)
  AND ABS(frequency - 50) > 0.5
ORDER BY time DESC
```

---

## Error Handling

All APIs follow a consistent error response format:

```json
{
  "error": {
    "code": "VOLTAGE_OUT_OF_RANGE",
    "message": "Voltage reading 380V exceeds maximum 400V for single-phase meter",
    "meter_id": "METER-0001",
    "timestamp": "2026-05-28T10:00:00Z",
    "request_id": "req-abc123"
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|------------|-------------|
| `INVALID_SCHEMA` | 400 | Message does not match expected schema |
| `STALE_DATA` | 400 | Data timestamp exceeds freshness threshold |
| `DUPLICATE_RECORD` | 409 | Record already processed (dedup) |
| `BUDGET_EXCEEDED` | 402 | Monthly budget limit reached |
| `METER_NOT_FOUND` | 404 | Meter ID not registered in IoT Core |
| `REGION_UNAVAILABLE` | 503 | AWS service not available in target region |

---

*API Reference v1.0 — GridForge by HarchCorp S.A. — AWS Prompt the Planet Challenge 2026*
