"""
GridForge — Anomaly Detection Lambda
Processes Kinesis telemetry records, applies rule-based thresholds
and ML model scoring, publishes critical events to SNS.

Runtime: Python 3.11 | Architecture: arm64 (Graviton)
Memory: 1024 MB | Timeout: 120s
"""

import json
import os
import base64
import logging
import math
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import boto3

# ============================================================
# Configuration
# ============================================================

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "")
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
SAGEMAKER_ENDPOINT = os.environ.get("SAGEMAKER_ENDPOINT", "")

# Grid anomaly thresholds (IEEE 1159 / IEC 61000-4-30)
VOLTAGE_NOMINAL = 230.0  # V (Sub-Saharan African standard)
VOLTAGE_SAG_THRESHOLD = 0.9  # 90% of nominal = 207V
VOLTAGE_SWELL_THRESHOLD = 1.1  # 110% of nominal = 253V
FREQUENCY_NOMINAL = 50.0  # Hz (African standard)
FREQUENCY_DEVIATION_MAX = 0.5  # Hz
POWER_FACTOR_MIN = 0.85  # Minimum acceptable power factor
CURRENT_OVERLOAD_FACTOR = 1.2  # 120% of rated capacity

# Severity classification
SEVERITY_LOW = "LOW"
SEVERITY_MEDIUM = "MEDIUM"
SEVERITY_HIGH = "HIGH"
SEVERITY_CRITICAL = "CRITICAL"

logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

# AWS clients (initialized outside handler for connection reuse)
sns_client = boto3.client("sns")
events_client = boto3.client("events")
dynamodb = boto3.resource("dynamodb")
sagemaker_runtime = boto3.client("sagemaker-runtime")


class GridAnomaly:
    """Represents a detected grid anomaly with severity classification."""

    def __init__(
        self,
        meter_id: str,
        anomaly_type: str,
        severity: str,
        value: float,
        threshold: float,
        unit: str,
        substation_id: str = "unknown",
        region: str = "unknown",
        timestamp: str = None,
    ):
        self.meter_id = meter_id
        self.anomaly_type = anomaly_type
        self.severity = severity
        self.value = value
        self.threshold = threshold
        self.unit = unit
        self.substation_id = substation_id
        self.region = region
        self.timestamp = timestamp or datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "meter_id": self.meter_id,
            "anomaly_type": self.anomaly_type,
            "severity": self.severity,
            "value": self.value,
            "threshold": self.threshold,
            "unit": self.unit,
            "substation_id": self.substation_id,
            "region": self.region,
            "timestamp": self.timestamp,
        }


def decode_kinesis_record(record: Dict) -> Optional[Dict]:
    """Decode a Kinesis record from base64."""
    try:
        payload = base64.b64decode(record["kinesis"]["data"])
        return json.loads(payload)
    except (json.JSONDecodeError, KeyError) as e:
        logger.error(f"Failed to decode Kinesis record: {e}")
        return None


def classify_voltage_severity(voltage: float) -> Tuple[str, float]:
    """Classify voltage anomaly severity based on IEEE 1159."""
    ratio = voltage / VOLTAGE_NOMINAL

    if voltage < VOLTAGE_NOMINAL * 0.5:
        return SEVERITY_CRITICAL, VOLTAGE_NOMINAL * 0.5
    elif voltage < VOLTAGE_NOMINAL * 0.7:
        return SEVERITY_HIGH, VOLTAGE_NOMINAL * 0.7
    elif voltage < VOLTAGE_NOMINAL * VOLTAGE_SAG_THRESHOLD:
        return SEVERITY_MEDIUM, VOLTAGE_NOMINAL * VOLTAGE_SAG_THRESHOLD
    elif voltage > VOLTAGE_NOMINAL * 1.3:
        return SEVERITY_CRITICAL, VOLTAGE_NOMINAL * 1.3
    elif voltage > VOLTAGE_NOMINAL * VOLTAGE_SWELL_THRESHOLD:
        return SEVERITY_MEDIUM, VOLTAGE_NOMINAL * VOLTAGE_SWELL_THRESHOLD
    else:
        return SEVERITY_LOW, VOLTAGE_NOMINAL


def classify_frequency_severity(frequency: float) -> Tuple[str, float]:
    """Classify frequency deviation severity."""
    deviation = abs(frequency - FREQUENCY_NOMINAL)

    if deviation > 2.0:
        return SEVERITY_CRITICAL, FREQUENCY_NOMINAL + 2.0
    elif deviation > 1.0:
        return SEVERITY_HIGH, FREQUENCY_NOMINAL + 1.0
    elif deviation > FREQUENCY_DEVIATION_MAX:
        return SEVERITY_MEDIUM, FREQUENCY_NOMINAL + FREQUENCY_DEVIATION_MAX
    else:
        return SEVERITY_LOW, FREQUENCY_NOMINAL


def classify_power_factor_severity(pf: float) -> Tuple[str, float]:
    """Classify power factor severity (lower = worse)."""
    if pf < 0.5:
        return SEVERITY_CRITICAL, 0.5
    elif pf < 0.7:
        return SEVERITY_HIGH, 0.7
    elif pf < POWER_FACTOR_MIN:
        return SEVERITY_MEDIUM, POWER_FACTOR_MIN
    else:
        return SEVERITY_LOW, POWER_FACTOR_MIN


def detect_anomalies(reading: Dict) -> List[GridAnomaly]:
    """Apply rule-based anomaly detection to a single meter reading."""
    anomalies = []

    meter_id = reading.get("meter_id", "unknown")
    substation_id = reading.get("substation_id", "unknown")
    region = reading.get("region", "unknown")
    timestamp = reading.get("timestamp", datetime.now(timezone.utc).isoformat())

    # Voltage check
    voltage = reading.get("voltage")
    if voltage is not None:
        severity, threshold = classify_voltage_severity(voltage)
        if severity != SEVERITY_LOW:
            anomalies.append(
                GridAnomaly(
                    meter_id=meter_id,
                    anomaly_type="voltage_anomaly",
                    severity=severity,
                    value=voltage,
                    threshold=threshold,
                    unit="V",
                    substation_id=substation_id,
                    region=region,
                    timestamp=timestamp,
                )
            )

    # Frequency check
    frequency = reading.get("frequency")
    if frequency is not None:
        severity, threshold = classify_frequency_severity(frequency)
        if severity != SEVERITY_LOW:
            anomalies.append(
                GridAnomaly(
                    meter_id=meter_id,
                    anomaly_type="frequency_deviation",
                    severity=severity,
                    value=frequency,
                    threshold=threshold,
                    unit="Hz",
                    substation_id=substation_id,
                    region=region,
                    timestamp=timestamp,
                )
            )

    # Power factor check
    power_factor = reading.get("power_factor")
    if power_factor is not None:
        severity, threshold = classify_power_factor_severity(power_factor)
        if severity != SEVERITY_LOW:
            anomalies.append(
                GridAnomaly(
                    meter_id=meter_id,
                    anomaly_type="low_power_factor",
                    severity=severity,
                    value=power_factor,
                    threshold=threshold,
                    unit="cos(phi)",
                    substation_id=substation_id,
                    region=region,
                    timestamp=timestamp,
                )
            )

    return anomalies


def get_ml_prediction(reading: Dict) -> Optional[Dict]:
    """Query SageMaker endpoint for ML-based anomaly prediction."""
    if not SAGEMAKER_ENDPOINT:
        return None

    try:
        payload = {
            "voltage": reading.get("voltage", 0),
            "current": reading.get("current", 0),
            "frequency": reading.get("frequency", 50),
            "power_factor": reading.get("power_factor", 1.0),
            "hour_of_day": datetime.now(timezone.utc).hour,
            "day_of_week": datetime.now(timezone.utc).weekday(),
        }

        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,
            ContentType="application/json",
            Body=json.dumps(payload),
        )

        result = json.loads(response["Body"].read().decode())
        return result

    except Exception as e:
        logger.warning(f"SageMaker prediction failed: {e}")
        return None


def publish_to_sns(anomaly: GridAnomaly) -> None:
    """Publish critical/high severity anomaly to SNS for immediate notification."""
    if anomaly.severity not in [SEVERITY_CRITICAL, SEVERITY_HIGH]:
        return

    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not configured, skipping notification")
        return

    subject = f"GridForge Alert: {anomaly.anomaly_type} [{anomaly.severity}] at {anomaly.meter_id}"
    message = json.dumps({
        "default": json.dumps(anomaly.to_dict()),
        "email": (
            f"GridForge Alert\n\n"
            f"Type: {anomaly.anomaly_type}\n"
            f"Severity: {anomaly.severity}\n"
            f"Meter: {anomaly.meter_id}\n"
            f"Substation: {anomaly.substation_id}\n"
            f"Value: {anomaly.value} {anomaly.unit}\n"
            f"Threshold: {anomaly.threshold} {anomaly.unit}\n"
            f"Region: {anomaly.region}\n"
            f"Time: {anomaly.timestamp}\n"
        ),
    }, indent=2)

    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject=subject,
            MessageStructure="json",
        )
        logger.info(f"Published {anomaly.severity} alert to SNS: {anomaly.anomaly_type}")
    except Exception as e:
        logger.error(f"Failed to publish to SNS: {e}")


def send_to_event_bridge(anomaly: GridAnomaly) -> None:
    """Send anomaly event to EventBridge for Step Functions orchestration."""
    if not EVENT_BUS_NAME:
        return

    try:
        events_client.put_events(
            Entries=[
                {
                    "EventBusName": EVENT_BUS_NAME,
                    "Source": "gridforge.anomaly-detector",
                    "DetailType": "Grid Anomaly Detected",
                    "Detail": json.dumps(anomaly.to_dict()),
                }
            ]
        )
        logger.info(f"Sent anomaly to EventBridge: {anomaly.anomaly_type}")
    except Exception as e:
        logger.error(f"Failed to send to EventBridge: {e}")


def log_to_dynamodb(anomaly: GridAnomaly) -> None:
    """Log anomaly to DynamoDB for audit trail and historical analysis."""
    if not DYNAMODB_TABLE:
        return

    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.put_item(
            Item={
                "meter_id": anomaly.meter_id,
                "timestamp": anomaly.timestamp,
                "anomaly_type": anomaly.anomaly_type,
                "severity": anomaly.severity,
                "value": anomaly.value,
                "threshold": anomaly.threshold,
                "unit": anomaly.unit,
                "substation_id": anomaly.substation_id,
                "region": anomaly.region,
                "ttl": int(datetime.now(timezone.utc).timestamp()) + (365 * 24 * 3600),
            }
        )
    except Exception as e:
        logger.error(f"Failed to log to DynamoDB: {e}")


def lambda_handler(event: Dict, context: Any) -> Dict:
    """Main Lambda handler — processes Kinesis records and detects anomalies."""
    logger.info(f"Processing {len(event.get('Records', []))} Kinesis records")

    anomalies_found = []
    records_processed = 0

    for record in event.get("Records", []):
        reading = decode_kinesis_record(record)
        if not reading:
            continue

        records_processed += 1

        # Rule-based anomaly detection
        anomalies = detect_anomalies(reading)
        anomalies_found.extend(anomalies)

        # ML-based prediction (if SageMaker endpoint is configured)
        ml_result = get_ml_prediction(reading)
        if ml_result and ml_result.get("anomaly_probability", 0) > 0.8:
            anomalies.append(
                GridAnomaly(
                    meter_id=reading.get("meter_id", "unknown"),
                    anomaly_type="ml_predicted_anomaly",
                    severity=SEVERITY_HIGH if ml_result["anomaly_probability"] > 0.95 else SEVERITY_MEDIUM,
                    value=ml_result["anomaly_probability"],
                    threshold=0.8,
                    unit="probability",
                    substation_id=reading.get("substation_id", "unknown"),
                    region=reading.get("region", "unknown"),
                )
            )

        # Process each detected anomaly
        for anomaly in anomalies:
            publish_to_sns(anomaly)
            send_to_event_bridge(anomaly)
            log_to_dynamodb(anomaly)

    logger.info(
        f"Processed {records_processed} records, found {len(anomalies_found)} anomalies"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "records_processed": records_processed,
            "anomalies_found": len(anomalies_found),
            "anomalies": [a.to_dict() for a in anomalies_found[:10]],  # First 10 only
        }),
    }
