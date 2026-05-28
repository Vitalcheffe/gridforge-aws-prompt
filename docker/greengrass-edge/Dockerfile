# GridForge — Greengrass Edge Gateway Docker Image
# ==================================================
# Simulates an AWS Greengrass edge gateway running at a grid substation.
# Used for local development and testing of edge anomaly detection.
#
# In production, this would run on an AWS IoT Greengrass Core device
# (e.g., Raspberry Pi 4 or NVIDIA Jetson) at each substation.
#
# Author: HarchCorp S.A. — AWS Prompt the Planet Challenge 2026

FROM python:3.11-slim

LABEL maintainer="HarchCorp S.A."
LABEL description="GridForge Greengrass Edge Gateway for Smart Grid Anomaly Detection"
LABEL version="1.0.0"

# ── System dependencies ────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# ── Python dependencies ────────────────────────────────────────────────────
WORKDIR /opt/gridforge-edge

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Application code ───────────────────────────────────────────────────────
COPY edge-model.py .
COPY config.json .

# ── Runtime configuration ──────────────────────────────────────────────────
ENV MQTT_BROKER="a1b2c3d4e5f6-ats.iot.af-south-1.amazonaws.com"
ENV MQTT_PORT=8883
ENV DEVICE_ID="edge-gateway-001"
ENV SUBSTATION_ID="substation-accra-01"
ENV REGION="af-south-1"
ENV ANOMALY_THRESHOLD_VOLTAGE_LOW=180.0
ENV ANOMALY_THRESHOLD_VOLTAGE_HIGH=260.0
ENV ANOMALY_THRESHOLD_FREQUENCY_DEV=0.5
ENV PUBLISH_INTERVAL_SEC=5
ENV LOG_LEVEL=INFO

# ── Health check ───────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# ── Expose metrics port ────────────────────────────────────────────────────
EXPOSE 8080

# ── Run the edge model ────────────────────────────────────────────────────
CMD ["python", "edge-model.py", "--config", "config.json"]
