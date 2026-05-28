"""
GridForge — Edge Anomaly Detection Model
==========================================
Runs on Greengrass edge gateways at grid substations.
Performs local, real-time anomaly detection on meter telemetry
before forwarding to AWS IoT Core.

Architecture:
- TensorFlow Lite model for voltage sag detection
- Rule-based fallback for frequency and power factor anomalies
- MQTT publisher for AWS IoT Core integration
- Local buffer for intermittent connectivity (store-and-forward)
- IEEE 1159 voltage classification at the edge

Sub-Saharan African grid parameters:
- Nominal voltage: 230V (single-phase) / 400V (three-phase)
- Nominal frequency: 50Hz
- Tolerance: ±10% (207V–253V per IEC 60038)
- Critical threshold: ±22% (180V–260V)

Author: HarchCorp S.A. — AWS Prompt the Planet Challenge 2026
"""

import json
import time
import os
import signal
import sys
import logging
import hashlib
from datetime import datetime, timezone
from dataclasses import dataclass, asdict
from typing import Optional, List
from enum import Enum

# ── Configuration ──────────────────────────────────────────────────────────
try:
    import yaml
except ImportError:
    yaml = None

try:
    import paho.mqtt.client as mqtt
except ImportError:
    mqtt = None  # Graceful degradation without MQTT

try:
    import numpy as np
except ImportError:
    np = None  # Rule-based fallback without numpy

try:
    import tflite_runtime.interpreter as tflite
except ImportError:
    try:
        import tensorflow as tf
        tflite = None  # Use full TF as fallback
    except ImportError:
        tf = None  # Rule-based only

# ── Logging ────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("gridforge-edge")

# ── IEEE 1159 Voltage Classification ──────────────────────────────────────
class VoltageClass(Enum):
    """IEEE 1159 voltage disturbance classification for 230V systems."""
    NORMAL = "NORMAL"              # 207V - 253V (±10%)
    SWELL_MODERATE = "SWELL_MOD"   # 253V - 276V (+10% to +20%)
    SWELL_SEVERE = "SWELL_SEV"     # > 276V (+20%)
    SAG_MODERATE = "SAG_MOD"       # 184V - 207V (-10% to -20%)
    SAG_SEVERE = "SAG_SEV"         # 161V - 184V (-20% to -30%)
    SAG_CRITICAL = "SAG_CRIT"      # < 161V (< -30%)
    INTERRUPTION = "INTERRUPTION"  # < 46V (< 10%)


@dataclass
class MeterReading:
    """Smart meter telemetry reading."""
    meter_id: str
    timestamp: float
    voltage: float
    current: float
    frequency: float
    power_factor: float
    substation_id: Optional[str] = None
    region: Optional[str] = None
    utility_name: Optional[str] = None


@dataclass
class AnomalyResult:
    """Edge anomaly detection result."""
    meter_id: str
    timestamp: float
    is_anomalous: bool
    voltage_class: str
    frequency_deviation: float
    power_factor_low: bool
    severity: str  # LOW | MEDIUM | HIGH | CRITICAL
    confidence: float  # 0.0 - 1.0
    recommended_action: str
    edge_gateway_id: str
    processing_latency_ms: float


class EdgeAnomalyDetector:
    """
    Edge-based anomaly detection for smart grid telemetry.
    Combines TensorFlow Lite ML inference with rule-based fallback.
    """

    def __init__(self, config: dict):
        self.config = config
        self.device_id = config.get("device_id", "edge-gateway-001")
        self.substation_id = config.get("substation_id", "substation-unknown")

        # Thresholds for Sub-Saharan African 230V/50Hz grids
        self.voltage_nominal = config.get("voltage_nominal", 230.0)
        self.frequency_nominal = config.get("frequency_nominal", 50.0)
        self.voltage_low_critical = config.get("voltage_low_critical", 180.0)
        self.voltage_high_critical = config.get("voltage_high_critical", 260.0)
        self.frequency_dev_threshold = config.get("frequency_dev_threshold", 0.5)
        self.power_factor_threshold = config.get("power_factor_threshold", 0.85)

        # ML model
        self.interpreter = None
        self._load_model()

        # MQTT client for AWS IoT Core
        self.mqtt_client = None
        self._setup_mqtt()

        # Local buffer for intermittent connectivity
        self.buffer: List[dict] = []
        self.buffer_max_size = config.get("buffer_max_size", 1000)

        logger.info(
            f"EdgeAnomalyDetector initialized: device={self.device_id}, "
            f"substation={self.substation_id}"
        )

    def _load_model(self):
        """Load TensorFlow Lite model for voltage sag detection."""
        model_path = self.config.get("model_path", "voltage_sag_model.tflite")

        try:
            if tflite:
                self.interpreter = tflite.Interpreter(model_path=model_path)
                self.interpreter.allocate_tensors()
                logger.info("TensorFlow Lite model loaded successfully")
            elif tf:
                self.interpreter = tf.lite.Interpreter(model_path=model_path)
                self.interpreter.allocate_tensors()
                logger.info("TensorFlow Lite model loaded (via full TF)")
            else:
                logger.warning(
                    "No ML runtime available — using rule-based detection only"
                )
        except Exception as e:
            logger.warning(f"Failed to load ML model: {e} — falling back to rules")
            self.interpreter = None

    def _setup_mqtt(self):
        """Set up MQTT client for AWS IoT Core connectivity."""
        if mqtt is None:
            logger.warning("paho-mqtt not available — MQTT publishing disabled")
            return

        try:
            self.mqtt_client = mqtt.Client(client_id=self.device_id)
            cert_path = self.config.get("cert_path", "certs/")
            self.mqtt_client.tls_set(
                ca_certs=f"{cert_path}/root-ca.pem",
                certfile=f"{cert_path}/device.pem.crt",
                keyfile=f"{cert_path}/private.pem.key",
            )
            broker = self.config.get("mqtt_broker", "localhost")
            port = self.config.get("mqtt_port", 8883)
            self.mqtt_client.connect(broker, port, keepalive=60)
            self.mqtt_client.loop_start()
            logger.info(f"MQTT connected to {broker}:{port}")
        except Exception as e:
            logger.warning(f"MQTT connection failed: {e} — operating in offline mode")
            self.mqtt_client = None

    def classify_voltage(self, voltage: float) -> VoltageClass:
        """
        Classify voltage reading according to IEEE 1159 standards
        adapted for 230V nominal Sub-Saharan African grids.
        """
        pct_deviation = ((voltage - self.voltage_nominal) / self.voltage_nominal) * 100

        if pct_deviation > 20:
            return VoltageClass.SWELL_SEVERE
        elif pct_deviation > 10:
            return VoltageClass.SWELL_MODERATE
        elif pct_deviation > -10:
            return VoltageClass.NORMAL
        elif pct_deviation > -20:
            return VoltageClass.SAG_MODERATE
        elif pct_deviation > -30:
            return VoltageClass.SAG_SEVERE
        elif voltage > 46:
            return VoltageClass.SAG_CRITICAL
        else:
            return VoltageClass.INTERRUPTION

    def ml_predict(self, reading: MeterReading) -> Optional[dict]:
        """
        Run TensorFlow Lite inference on the meter reading.
        Returns ML prediction or None if model unavailable.
        """
        if self.interpreter is None:
            return None

        try:
            input_details = self.interpreter.get_input_details()
            output_details = self.interpreter.get_output_details()

            # Prepare input: [voltage, current, frequency, power_factor]
            if np:
                input_data = np.array(
                    [[reading.voltage, reading.current, reading.frequency, reading.power_factor]],
                    dtype=np.float32,
                )
            else:
                input_data = [[reading.voltage, reading.current, reading.frequency, reading.power_factor]]

            self.interpreter.set_tensor(input_details[0]["index"], input_data)
            self.interpreter.invoke()

            output = self.interpreter.get_tensor(output_details[0]["index"])

            return {
                "anomaly_score": float(output[0][0]),
                "prediction": "ANOMALOUS" if output[0][0] > 0.7 else "NORMAL",
            }

        except Exception as e:
            logger.error(f"ML prediction failed: {e}")
            return None

    def detect_anomaly(self, reading: MeterReading) -> AnomalyResult:
        """
        Main anomaly detection: combines ML prediction with rule-based checks.
        """
        start = time.time()

        # Step 1: Voltage classification (IEEE 1159)
        voltage_class = self.classify_voltage(reading.voltage)

        # Step 2: Frequency deviation check
        freq_deviation = abs(reading.frequency - self.frequency_nominal)

        # Step 3: Power factor check
        pf_low = reading.power_factor < self.power_factor_threshold

        # Step 4: ML prediction (if available)
        ml_result = self.ml_predict(reading)
        ml_anomalous = ml_result and ml_result.get("prediction") == "ANOMALOUS"

        # Step 5: Combine signals for severity determination
        severity = "LOW"
        is_anomalous = False
        recommended_action = "MONITOR"
        confidence = 0.5

        if voltage_class == VoltageClass.INTERRUPTION:
            severity = "CRITICAL"
            is_anomalous = True
            recommended_action = "ISOLATE_SEGMENT"
            confidence = 0.99
        elif voltage_class == VoltageClass.SAG_CRITICAL:
            severity = "CRITICAL"
            is_anomalous = True
            recommended_action = "ISOLATE_SEGMENT"
            confidence = 0.95
        elif voltage_class in (VoltageClass.SAG_SEVERE, VoltageClass.SWELL_SEVERE):
            severity = "HIGH"
            is_anomalous = True
            recommended_action = "ALERT_OPERATORS"
            confidence = 0.90
        elif voltage_class in (VoltageClass.SAG_MODERATE, VoltageClass.SWELL_MODERATE):
            severity = "MEDIUM"
            is_anomalous = True
            recommended_action = "LOG_AND_MONITOR"
            confidence = 0.80
        elif freq_deviation > self.frequency_dev_threshold:
            severity = "HIGH" if freq_deviation > 1.0 else "MEDIUM"
            is_anomalous = True
            recommended_action = "ALERT_OPERATORS"
            confidence = 0.85
        elif pf_low:
            severity = "LOW"
            is_anomalous = True
            recommended_action = "LOG_AND_MONITOR"
            confidence = 0.70
        elif ml_anomalous:
            severity = "MEDIUM"
            is_anomalous = True
            recommended_action = "LOG_AND_MONITOR"
            confidence = ml_result.get("anomaly_score", 0.5)

        # Step 6: Confidence adjustment based on multiple signals
        signal_count = sum([
            voltage_class != VoltageClass.NORMAL,
            freq_deviation > self.frequency_dev_threshold,
            pf_low,
            ml_anomalous,
        ])
        if signal_count >= 3:
            confidence = min(1.0, confidence + 0.15)
            if severity != "CRITICAL":
                severity = "HIGH"
                recommended_action = "ALERT_OPERATORS"

        latency_ms = (time.time() - start) * 1000

        return AnomalyResult(
            meter_id=reading.meter_id,
            timestamp=reading.timestamp,
            is_anomalous=is_anomalous,
            voltage_class=voltage_class.value,
            frequency_deviation=round(freq_deviation, 3),
            power_factor_low=pf_low,
            severity=severity,
            confidence=round(confidence, 2),
            recommended_action=recommended_action,
            edge_gateway_id=self.device_id,
            processing_latency_ms=round(latency_ms, 2),
        )

    def publish_result(self, result: AnomalyResult):
        """
        Publish anomaly detection result to AWS IoT Core via MQTT.
        Uses store-and-forward pattern for intermittent connectivity.
        """
        topic = f"gridforge/anomaly/{self.substation_id}/{result.meter_id}"
        payload = json.dumps(asdict(result))

        if self.mqtt_client:
            try:
                self.mqtt_client.publish(topic, payload, qos=1)
                logger.debug(f"Published to {topic}")

                # Flush buffer if reconnected
                self._flush_buffer()
                return
            except Exception as e:
                logger.warning(f"MQTT publish failed: {e} — buffering")

        # Buffer for later delivery (store-and-forward)
        self.buffer.append({"topic": topic, "payload": payload})
        if len(self.buffer) > self.buffer_max_size:
            self.buffer = self.buffer[-self.buffer_max_size:]  # Keep newest
            logger.warning("Buffer overflow — dropping oldest messages")

    def _flush_buffer(self):
        """Flush buffered messages when connectivity is restored."""
        if not self.buffer or not self.mqtt_client:
            return

        flushed = 0
        for msg in self.buffer[:]:
            try:
                self.mqtt_client.publish(msg["topic"], msg["payload"], qos=1)
                self.buffer.remove(msg)
                flushed += 1
            except Exception:
                break

        if flushed:
            logger.info(f"Flushed {flushed} buffered messages")

    def process_reading(self, reading: MeterReading) -> AnomalyResult:
        """
        Process a single meter reading through the full pipeline:
        detect anomaly → publish result.
        """
        result = self.detect_anomaly(reading)

        if result.is_anomalous:
            logger.info(
                f"ANOMALY DETECTED: meter={reading.meter_id} "
                f"severity={result.severity} voltage_class={result.voltage_class} "
                f"action={result.recommended_action}"
            )
            self.publish_result(result)
        else:
            logger.debug(f"Normal reading: meter={reading.meter_id}")

        return result


def load_config(config_path: str) -> dict:
    """Load configuration from JSON or YAML file."""
    with open(config_path, "r") as f:
        content = f.read()

    if config_path.endswith(".json"):
        return json.loads(content)
    elif config_path.endswith((".yaml", ".yml")) and yaml:
        return yaml.safe_load(content)
    else:
        return json.loads(content)


def run_simulation(config: dict, duration_sec: int = 60):
    """
    Run a local simulation with synthetic meter data.
    Used for development and testing without real hardware.
    """
    detector = EdgeAnomalyDetector(config)

    logger.info(f"Starting edge simulation for {duration_sec} seconds...")

    # Simulate meter readings with realistic African grid patterns
    meter_ids = [f"METER-{i:04d}" for i in range(1, 11)]  # 10 test meters
    start_time = time.time()
    reading_count = 0

    while time.time() - start_time < duration_sec:
        for meter_id in meter_ids:
            # Simulate realistic 230V grid telemetry
            import random
            voltage = 230.0 + random.gauss(0, 8)  # Normal distribution around 230V
            current = random.uniform(5, 50)  # 5-50A
            frequency = 50.0 + random.gauss(0, 0.1)  # 50Hz ± 0.1Hz
            power_factor = random.uniform(0.85, 0.98)

            # Inject anomalies (5% chance)
            if random.random() < 0.05:
                anomaly_type = random.choice(["sag", "swell", "freq_dev", "low_pf"])
                if anomaly_type == "sag":
                    voltage = random.uniform(140, 190)
                elif anomaly_type == "swell":
                    voltage = random.uniform(265, 300)
                elif anomaly_type == "freq_dev":
                    frequency = 50.0 + random.uniform(0.8, 2.0)
                elif anomaly_type == "low_pf":
                    power_factor = random.uniform(0.4, 0.75)

            reading = MeterReading(
                meter_id=meter_id,
                timestamp=time.time(),
                voltage=round(voltage, 2),
                current=round(current, 2),
                frequency=round(frequency, 3),
                power_factor=round(power_factor, 3),
                substation_id=config.get("substation_id", "test-substation"),
                utility_name=config.get("utility_name", "Test-Utility"),
            )

            detector.process_reading(reading)
            reading_count += 1

        time.sleep(5)  # 5-second interval

    logger.info(
        f"Simulation complete: {reading_count} readings processed in {duration_sec}s"
    )


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="GridForge Edge Anomaly Detector")
    parser.add_argument("--config", default="config.json", help="Path to config file")
    parser.add_argument("--simulate", action="store_true", help="Run simulation mode")
    parser.add_argument("--duration", type=int, default=60, help="Simulation duration (sec)")
    args = parser.parse_args()

    config = load_config(args.config)

    if args.simulate:
        run_simulation(config, args.duration)
    else:
        # Production mode: listen for meter data on serial/MQTT
        logger.info("Starting GridForge Edge Gateway in production mode...")
        detector = EdgeAnomalyDetector(config)
        logger.info("Edge gateway ready. Waiting for meter data...")

        # Graceful shutdown
        def shutdown_handler(signum, frame):
            logger.info("Shutting down gracefully...")
            sys.exit(0)

        signal.signal(signal.SIGINT, shutdown_handler)
        signal.signal(signal.SIGTERM, shutdown_handler)

        # Keep running
        while True:
            time.sleep(1)
