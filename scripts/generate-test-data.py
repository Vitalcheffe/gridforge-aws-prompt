"""
GridForge — Synthetic Meter Data Generator
Generates realistic smart meter telemetry for testing.

Usage: python3 generate-test-data.py --meters 100 --interval 5
"""

import argparse
import json
import random
import time
from datetime import datetime, timezone
from typing import Dict, List

# ============================================================
# Realistic Grid Parameters for Sub-Saharan Africa
# ============================================================

# Voltage distribution (230V nominal, with realistic variance)
VOLTAGE_MEAN = 230.0
VOLTAGE_STD = 8.0  # Standard deviation
VOLTAGE_SAG_PROBABILITY = 0.02  # 2% chance of voltage sag per reading
VOLTAGE_SWELL_PROBABILITY = 0.005  # 0.5% chance of voltage swell

# Frequency distribution (50Hz nominal)
FREQUENCY_MEAN = 50.0
FREQUENCY_STD = 0.05  # Very tight distribution normally

# Power factor (0.85-0.98 typical for African utilities)
POWER_FACTOR_MIN = 0.75
POWER_FACTOR_MAX = 0.99

# Current distribution (varies by time of day and region)
CURRENT_RESIDENTIAL_MEAN = 15.0  # Amps
CURRENT_RESIDENTIAL_STD = 8.0
CURRENT_COMMERCIAL_MEAN = 45.0
CURRENT_COMMERCIAL_STD = 20.0

# Sub-Saharan African regions for test data
REGIONS = [
    "greater-accra",
    "ashanti",
    "western-gh",
    "lagos-mainland",
    "ikeja",
    "abuja-central",
    "kigali-city",
    "nairobi-west",
    "dar-es-salaam-south",
    "dakar-plateau",
]

SUBSTATIONS = {
    "greater-accra": ["ACH", "TEM", "TMA", "KAN", "EAS"],
    "ashanti": ["KUM", "OBU", "SUN"],
    "lagos-mainland": ["IKE", "SUR", "LAG", "YAB"],
    "ikeja": ["IKe1", "IKe2", "IKe3"],
    "abuja-central": ["ABJ1", "ABJ2", "WUS"],
    "kigali-city": ["KGL1", "KGL2", "KGL3"],
}


def generate_meter_id(region: str, index: int) -> str:
    """Generate a realistic meter ID."""
    return f"GF-{region[:3].upper()}-{index:05d}"


def generate_voltage(hour: int, inject_anomaly: bool = False) -> float:
    """Generate realistic voltage reading based on time of day."""
    # Time-of-day effect: lower voltage during peak hours (18:00-22:00)
    if 18 <= hour <= 22:
        base = VOLTAGE_MEAN - random.uniform(5, 15)  # Peak demand voltage drop
    elif 0 <= hour <= 5:
        base = VOLTAGE_MEAN + random.uniform(2, 8)  # Light load, higher voltage
    else:
        base = VOLTAGE_MEAN

    voltage = base + random.gauss(0, VOLTAGE_STD)

    if inject_anomaly:
        anomaly_type = random.choices(
            ["sag", "swell", "interruption"],
            weights=[0.6, 0.3, 0.1],
        )[0]
        if anomaly_type == "sag":
            voltage = VOLTAGE_MEAN * random.uniform(0.5, 0.8)
        elif anomaly_type == "swell":
            voltage = VOLTAGE_MEAN * random.uniform(1.15, 1.3)
        elif anomaly_type == "interruption":
            voltage = 0.0

    return round(max(0.0, min(400.0, voltage)), 1)


def generate_frequency(inject_anomaly: bool = False) -> float:
    """Generate realistic frequency reading."""
    frequency = FREQUENCY_MEAN + random.gauss(0, FREQUENCY_STD)

    if inject_anomaly:
        frequency = FREQUENCY_MEAN + random.choice([-1.5, -1.0, 1.0, 1.5])

    return round(max(47.0, min(53.0, frequency)), 3)


def generate_power_factor(load_type: str) -> float:
    """Generate realistic power factor based on load type."""
    if load_type == "residential":
        return round(random.uniform(0.85, 0.98), 3)
    elif load_type == "commercial":
        return round(random.uniform(0.80, 0.95), 3)
    else:  # industrial
        return round(random.uniform(0.75, 0.90), 3)


def generate_current(hour: int, load_type: str) -> float:
    """Generate realistic current reading based on time and load type."""
    if load_type == "residential":
        base = CURRENT_RESIDENTIAL_MEAN
        std = CURRENT_RESIDENTIAL_STD
        # Peak residential usage 18:00-22:00
        if 18 <= hour <= 22:
            base *= 1.8
        elif 0 <= hour <= 5:
            base *= 0.3
    else:
        base = CURRENT_COMMERCIAL_MEAN
        std = CURRENT_COMMERCIAL_STD
        # Commercial peak 09:00-17:00
        if 9 <= hour <= 17:
            base *= 1.5
        elif 0 <= hour <= 6:
            base *= 0.2

    return round(max(0.0, random.gauss(base, std)), 2)


def generate_reading(
    meter_id: str,
    region: str,
    substation_id: str,
    hour: int,
    inject_anomaly: bool = False,
) -> Dict:
    """Generate a single meter reading."""
    load_type = random.choices(
        ["residential", "commercial", "industrial"],
        weights=[0.70, 0.20, 0.10],
    )[0]

    return {
        "meter_id": meter_id,
        "substation_id": substation_id,
        "region": region,
        "utility_name": "gridforge-test",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "voltage": generate_voltage(hour, inject_anomaly),
        "current": generate_current(hour, load_type),
        "frequency": generate_frequency(inject_anomaly),
        "power_factor": generate_power_factor(load_type),
        "load_type": load_type,
    }


def main():
    parser = argparse.ArgumentParser(description="GridForge Test Data Generator")
    parser.add_argument("--meters", type=int, default=100, help="Number of meters")
    parser.add_argument("--interval", type=int, default=5, help="Seconds between readings")
    parser.add_argument("--anomaly-rate", type=float, default=0.02, help="Probability of anomaly per reading")
    parser.add_argument("--output", type=str, default=None, help="Output file (default: stdout)")
    parser.add_argument("--count", type=int, default=1, help="Number of readings per meter")
    args = parser.parse_args()

    readings = []
    hour = datetime.now(timezone.utc).hour

    for i in range(args.meters):
        region = random.choice(REGIONS)
        substation = random.choice(SUBSTATIONS.get(region, ["UNK"]))
        meter_id = generate_meter_id(region, i + 1)

        for _ in range(args.count):
            inject_anomaly = random.random() < args.anomaly_rate
            reading = generate_reading(meter_id, region, substation, hour, inject_anomaly)
            readings.append(reading)

    output = json.dumps(readings, indent=2)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Generated {len(readings)} readings -> {args.output}")
    else:
        print(output)
        print(f"\n# Generated {len(readings)} readings", file=__import__("sys").stderr)


if __name__ == "__main__":
    main()
