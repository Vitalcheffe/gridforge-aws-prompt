#!/bin/bash
# GridForge — Cost Estimation Script
# Estimates monthly AWS costs based on meter count and region
# Usage: ./scripts/cost-estimate.sh [meter_count] [region]

set -euo pipefail

METER_COUNT="${1:-10000}"
REGION="${2:-af-south-1}"

echo "============================================================"
echo "  GridForge — Monthly Cost Estimate"
echo "  Region: $REGION | Meters: $METER_COUNT"
echo "============================================================"
echo ""

# Scale factors based on meter count
if [ "$METER_COUNT" -le 500 ]; then
    KINESIS_SHARDS=1
    TIMESTREAM_GB=5
    LAMBNESS_GB=1
    SAGEMAKER="serverless"
    BEDROCK_CALLS=100
elif [ "$METER_COUNT" -le 5000 ]; then
    KINESIS_SHARDS=2
    TIMESTREAM_GB=50
    LAMBNESS_GB=10
    SAGEMAKER="serverless"
    BEDROCK_CALLS=500
else
    KINESIS_SHARDS=4
    TIMESTREAM_GB=100
    LAMBNESS_GB=25
    SAGEMAKER="endpoint"
    BEDROCK_CALLS=2000
fi

# af-south-1 pricing (approximate, as of 2026)
# Prices are slightly higher than us-east-1 due to regional premiums

echo "Service                    | Estimated Cost"
echo "---------------------------|---------------"

# IoT Core: $0.08 per million messages + $0.015 per thing/month
IOT_MESSAGES=$(echo "$METER_COUNT * 288 * 30 / 1000000 * 80" | bc)  # 288 readings/day (5min interval)
IOT_THINGS=$(echo "$METER_COUNT * 0.015" | bc)
IOT_TOTAL=$(echo "scale=2; $IOT_MESSAGES / 1000000 + $IOT_THINGS" | bc)
printf "IoT Core                   | \$%.2f\n" "$IOT_TOTAL"

# Kinesis
KINESIS_COST=$(echo "scale=2; $KINESIS_SHARDS * 36.0" | bc)
printf "Kinesis (%d shards)        | \$%.2f\n" "$KINESIS_SHARDS" "$KINESIS_COST"

# Timestream
TIMESTREAM_COST=$(echo "scale=2; $TIMESTREAM_GB * 0.50 + 10" | bc)
printf "Timestream (%d GB)         | \$%.2f\n" "$TIMESTREAM_GB" "$TIMESTREAM_COST"

# Lambda (Graviton/ARM)
LAMBDA_COST=$(echo "scale=2; $LAMBNESS_GB * 0.0000166667 * 1000000 / 100 + 5" | bc)
printf "Lambda (Graviton)          | \$%.2f\n" "$LAMBDA_COST"

# Step Functions
SF_COST=$(echo "scale=2; $METER_COUNT * 0.000025 * 30" | bc)
printf "Step Functions             | \$%.2f\n" "$SF_COST"

# SageMaker
if [ "$SAGEMAKER" = "serverless" ]; then
    SM_COST=50
else
    SM_COST=200
fi
printf "SageMaker (%s)     | \$%.2f\n" "$SAGEMAKER" "$SM_COST"

# Bedrock
BEDROCK_COST=$(echo "scale=2; $BEDROCK_CALLS * 0.003" | bc)
printf "Bedrock (%d calls)        | \$%.2f\n" "$BEDROCK_CALLS" "$BEDROCK_COST"

# QuickSight
printf "QuickSight                 | \$40.00\n"

# S3 + Glue
S3_COST=$(echo "scale=2; $TIMESTREAM_GB * 0.023 + 10" | bc)
printf "S3 + Glue                  | \$%.2f\n" "$S3_COST"

# CloudWatch
printf "CloudWatch                 | \$30.00\n"

# Security services
printf "Security (GuardDuty, etc.) | \$50.00\n"

echo "---------------------------|---------------"

# Calculate total (simplified)
TOTAL=$(echo "scale=2; $IOT_TOTAL + $KINESIS_COST + $TIMESTREAM_COST + $LAMBDA_COST + $SF_COST + $SM_COST + $BEDROCK_COST + 40 + $S3_COST + 30 + 50" | bc)
printf "TOTAL ESTIMATED            | \$%.2f/month\n" "$TOTAL"

echo ""
echo "Comparison: On-premise SCADA = \$15,000+/month"
echo "Savings: ~$(echo "scale=0; (15000 - $TOTAL) / 150 * 100" | bc)%"
echo ""
echo "Note: Actual costs depend on usage patterns."
echo "Use AWS Cost Explorer for real-time monitoring."
