"""
GridForge — Grid Event Processor Lambda
Processes Step Functions events, classifies severity,
sends notifications, and orchestrates grid response.

Runtime: Python 3.11 | Architecture: arm64 (Graviton)
Memory: 512 MB | Timeout: 60s
"""

import json
import os
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import boto3

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
SES_SOURCE_EMAIL = os.environ.get("SES_SOURCE_EMAIL", "")
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
IOT_ENDPOINT = os.environ.get("IOT_ENDPOINT", "")

logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

sns_client = boto3.client("sns")
ses_client = boto3.client("ses")
dynamodb = boto3.resource("dynamodb")
iot_client = boto3.client("iot-data", endpoint_url=f"https://{IOT_ENDPOINT}" if IOT_ENDPOINT else None)


SEVERITY_LEVELS = {
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}

# Emergency contacts by region (configurable via environment)
EMERGENCY_CONTACTS = json.loads(os.environ.get("EMERGENCY_CONTACTS", "{}"))


def classify_grid_event(event_detail: Dict) -> Dict:
    """Classify a grid event and determine automated response actions."""
    anomaly_type = event_detail.get("anomaly_type", "unknown")
    severity = event_detail.get("severity", "LOW")
    meter_id = event_detail.get("meter_id", "unknown")
    substation_id = event_detail.get("substation_id", "unknown")
    region = event_detail.get("region", "unknown")
    value = event_detail.get("value", 0)
    threshold = event_detail.get("threshold", 0)

    # Determine response actions based on severity
    actions = []

    if severity == "CRITICAL":
        actions.extend([
            "isolate_segment",
            "notify_grid_operators",
            "log_incident",
            "generate_incident_report",
            "notify_regulator",
        ])
    elif severity == "HIGH":
        actions.extend([
            "notify_grid_operators",
            "log_incident",
            "generate_incident_report",
        ])
    elif severity == "MEDIUM":
        actions.extend([
            "log_incident",
            "notify_oncall",
        ])
    else:
        actions.append("log_incident")

    return {
        "event_id": f"{meter_id}-{int(datetime.now(timezone.utc).timestamp())}",
        "classification": {
            "anomaly_type": anomaly_type,
            "severity": severity,
            "severity_level": SEVERITY_LEVELS.get(severity, 0),
        },
        "affected_assets": {
            "meter_id": meter_id,
            "substation_id": substation_id,
            "region": region,
        },
        "measurements": {
            "value": value,
            "threshold": threshold,
            "deviation_pct": round(abs(value - threshold) / threshold * 100, 2) if threshold else 0,
        },
        "response_actions": actions,
        "requires_human_intervention": severity in ["HIGH", "CRITICAL"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def execute_isolate_segment(event: Dict) -> Dict:
    """Send isolation command to IoT device via IoT Core."""
    meter_id = event.get("affected_assets", {}).get("meter_id")
    if not meter_id or not IOT_ENDPOINT:
        logger.warning("Cannot isolate: missing meter_id or IoT endpoint")
        return {"status": "skipped", "reason": "missing_config"}

    try:
        iot_client.publish(
            topic=f"gridforge/commands/{meter_id}/isolate",
            payload=json.dumps({
                "command": "ISOLATE_SEGMENT",
                "reason": event.get("classification", {}).get("anomaly_type"),
                "severity": event.get("classification", {}).get("severity"),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }),
        )
        logger.info(f"Sent isolation command to meter {meter_id}")
        return {"status": "sent", "meter_id": meter_id}
    except Exception as e:
        logger.error(f"Failed to send isolation command: {e}")
        return {"status": "failed", "error": str(e)}


def send_notification(event: Dict, recipients: list) -> Dict:
    """Send SNS + SES notification to grid operators."""
    severity = event.get("classification", {}).get("severity", "LOW")
    anomaly_type = event.get("classification", {}).get("anomaly_type", "unknown")
    meter_id = event.get("affected_assets", {}).get("meter_id", "unknown")
    substation = event.get("affected_assets", {}).get("substation_id", "unknown")

    # SNS notification
    if SNS_TOPIC_ARN:
        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"GridForge {severity} Alert: {anomaly_type} at {substation}",
                Message=json.dumps(event, indent=2),
            )
        except Exception as e:
            logger.error(f"SNS publish failed: {e}")

    # SES email notification
    if SES_SOURCE_EMAIL and recipients:
        try:
            ses_client.send_email(
                Source=SES_SOURCE_EMAIL,
                Destination={"ToAddresses": recipients},
                Message={
                    "Subject": {"Data": f"GridForge {severity} Alert: {anomaly_type}"},
                    "Body": {
                        "Text": {
                            "Data": (
                                f"GRID EVENT ALERT\n\n"
                                f"Severity: {severity}\n"
                                f"Type: {anomaly_type}\n"
                                f"Meter: {meter_id}\n"
                                f"Substation: {substation}\n"
                                f"Deviation: {event.get('measurements', {}).get('deviation_pct', 0)}%\n"
                                f"Time: {event.get('timestamp')}\n\n"
                                f"Actions: {', '.join(event.get('response_actions', []))}\n"
                            )
                        }
                    },
                },
            )
        except Exception as e:
            logger.error(f"SES send failed: {e}")

    return {"status": "notified", "recipients": len(recipients)}


def log_incident(event: Dict) -> Dict:
    """Log incident to DynamoDB for audit trail."""
    if not DYNAMODB_TABLE:
        return {"status": "skipped"}

    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.put_item(
            Item={
                "incident_id": event.get("event_id"),
                "timestamp": event.get("timestamp"),
                "severity": event.get("classification", {}).get("severity"),
                "anomaly_type": event.get("classification", {}).get("anomaly_type"),
                "meter_id": event.get("affected_assets", {}).get("meter_id"),
                "substation_id": event.get("affected_assets", {}).get("substation_id"),
                "region": event.get("affected_assets", {}).get("region"),
                "actions_taken": event.get("response_actions", []),
                "ttl": int(datetime.now(timezone.utc).timestamp()) + (365 * 24 * 3600),
            }
        )
        return {"status": "logged"}
    except Exception as e:
        logger.error(f"DynamoDB log failed: {e}")
        return {"status": "failed", "error": str(e)}


def lambda_handler(event: Dict, context: Any) -> Dict:
    """Main handler — classifies grid events and executes response actions."""
    logger.info(f"Processing grid event: {json.dumps(event)[:500]}")

    # Classify the event
    classified = classify_grid_event(event.get("detail", event))

    # Execute response actions
    results = {}
    actions = classified.get("response_actions", [])

    if "isolate_segment" in actions:
        results["isolation"] = execute_isolate_segment(classified)

    if "notify_grid_operators" in actions:
        region = classified.get("affected_assets", {}).get("region", "default")
        recipients = EMERGENCY_CONTACTS.get(region, [])
        results["notification"] = send_notification(classified, recipients)

    if "log_incident" in actions:
        results["incident_log"] = log_incident(classified)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "event_classified": classified,
            "action_results": results,
        }),
    }
