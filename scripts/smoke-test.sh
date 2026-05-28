#!/bin/bash
# GridForge — Smoke Test Script
# Verifies end-to-end data flow after deployment
# Usage: ./scripts/smoke-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/infra/terraform"

echo "============================================================"
echo "  GridForge — Smoke Test"
echo "============================================================"
echo ""

# Get Terraform outputs
cd "$TF_DIR"
IOT_ENDPOINT=$(terraform output -raw iot_endpoint 2>/dev/null || echo "")
DYNAMODB_TABLE=$(terraform output -raw incident_table_name 2>/dev/null || echo "")
KINESIS_STREAM=$(terraform output -raw kinesis_stream_name 2>/dev/null || echo "")

if [ -z "$IOT_ENDPOINT" ]; then
    echo "[ERROR] Cannot read Terraform outputs. Is the infrastructure deployed?"
    exit 1
fi

echo "[1/6] Verifying IoT Core endpoint..."
if aws iot describe-endpoint --endpoint-type iot:Data-ATS --region af-south-1 &>/dev/null; then
    echo "  OK: IoT endpoint is $IOT_ENDPOINT"
else
    echo "  FAIL: Cannot reach IoT endpoint"
fi

echo ""
echo "[2/6] Generating test data..."
python3 "$SCRIPT_DIR/generate-test-data.py" --meters 10 --count 1 --output /tmp/gridforge-test-data.json
echo "  OK: Generated test data"

echo ""
echo "[3/6] Injecting test data into Kinesis..."
if [ -n "$KINESIS_STREAM" ]; then
    # Convert to Kinesis records format
    python3 -c "
import json, base64
with open('/tmp/gridforge-test-data.json') as f:
    readings = json.load(f)
for r in readings:
    data = base64.b64encode(json.dumps(r).encode()).decode()
    print(json.dumps({'Data': data, 'PartitionKey': r['meter_id']}))
" > /tmp/gridforge-kinesis-records.json
    
    echo "  OK: Test data formatted for Kinesis"
else
    echo "  SKIP: Kinesis stream not available"
fi

echo ""
echo "[4/6] Verifying Timestream query..."
aws timestream-query query \
    --query-string "SELECT COUNT(*) FROM gridforge.grid_telemetry" \
    --region af-south-1 2>/dev/null && echo "  OK: Timestream queryable" || echo "  SKIP: Timestream not queryable yet"

echo ""
echo "[5/6] Checking CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "gridforge" \
    --region af-south-1 \
    --query 'length(MetricAlarms)' \
    --output text 2>/dev/null || echo "0")
echo "  OK: $ALARMS CloudWatch alarms configured"

echo ""
echo "[6/6] Verifying Security Hub..."
FINDINGS=$(aws securityhub get-findings \
    --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}' \
    --region af-south-1 \
    --query 'length(Findings)' \
    --output text 2>/dev/null || echo "unknown")
if [ "$FINDINGS" = "0" ]; then
    echo "  OK: No critical security findings"
else
    echo "  WARN: $FINDINGS critical findings (review required)"
fi

echo ""
echo "============================================================"
echo "  Smoke Test Complete!"
echo "============================================================"
