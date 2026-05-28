# GridForge — IoT Ingestion Module
# IoT Core, Thing Groups, Rules Engine, Greengrass, Device Defender, Certificate Management
# Handles 10,000+ smart meter ingestion via MQTT

# ============================================================
# IoT Core Thing Group — Logical grouping for all smart meters
# ============================================================

resource "aws_iot_thing_group" "meters" {
  name = "${var.thing_group_name}"

  properties {
    description = "Smart meter device group for ${var.utility_name}"
    attribute_payload {
      attributes = {
        utility    = var.utility_name
        meterCount = tostring(var.meter_count)
        region     = var.region
      }
    }
  }

  tags = local.common_tags
}

# ============================================================
# IoT Core Thing Type — Defines meter device properties
# ============================================================

resource "aws_iot_thing_type" "smart_meter" {
  name = "${var.utility_name}-smart-meter"

  properties {
    description = "Smart meter device type for ${var.utility_name} grid monitoring"

    searchable_attributes = [
      "meter_id",
      "substation_id",
      "region",
      "utility_name",
      "meter_type"
    ]
  }

  tags = local.common_tags
}

# ============================================================
# IoT Core Policy — Device connection and publish permissions
# ============================================================

resource "aws_iot_policy" "meter_policy" {
  name = "${var.utility_name}-meter-policy"

  # Allow devices to connect
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iot:Connect"]
        Resource = ["arn:aws:iot:${var.region}:*:client/${var.utility_name}-*"]
        Condition = {
          Bool = {
            "iot:Connection.Thing.IsAttached" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish",
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${var.region}:*:topic/grid/telemetry/*",
          "arn:aws:iot:${var.region}:*:topic/grid/status/*",
          "arn:aws:iot:${var.region}:*:topicfilter/grid/telemetry/*",
          "arn:aws:iot:${var.region}:*:topicfilter/grid/commands/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["iot:Subscribe"]
        Resource = [
          "arn:aws:iot:${var.region}:*:topicfilter/grid/commands/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:GetThingShadow",
          "iot:UpdateThingShadow"
        ]
        Resource = ["arn:aws:iot:${var.region}:*:thing/${var.utility_name}-*"]
      }
    ]
  })
}

# ============================================================
# IoT Core Topic Rule — Route ALL telemetry to Timestream
# ============================================================

resource "aws_iot_topic_rule" "timestream_route" {
  name        = "${var.utility_name}-to-timestream"
  description = "Route all smart meter telemetry to Timestream for time-series storage"
  enabled     = true
  sql         = "SELECT * FROM 'grid/telemetry/+'"
  sql_version = "2016-03-23"

  timestream {
    database_name = var.timestream_database_name
    table_name    = var.timestream_table_name

    dimension {
      name  = "meter_id"
      value = "${var.utility_name}-${topic(3)}"
    }

    dimension {
      name  = "region"
      value = "'af-south-1'"
    }

    role_arn = aws_iam_role.iot_timestream.arn
  }

  tags = local.common_tags
}

# ============================================================
# IoT Core Topic Rule — Route CRITICAL events to Kinesis
# ============================================================

resource "aws_iot_topic_rule" "kinesis_critical_route" {
  name        = "${var.utility_name}-to-kinesis-critical"
  description = "Route critical voltage/frequency anomalies to Kinesis for real-time processing"
  enabled     = true
  sql         = "SELECT * FROM 'grid/telemetry/+' WHERE voltage < ${var.voltage_low_threshold} OR voltage > ${var.voltage_high_threshold} OR ABS(frequency - 50.0) > ${var.frequency_deviation}"
  sql_version = "2016-03-23"

  kinesis {
    stream_name = var.kinesis_stream_name
    partition_key = "${topic(3)}"
    role_arn    = aws_iam_role.iot_kinesis.arn
  }

  tags = local.common_tags
}

# ============================================================
# IoT Core Topic Rule — Route ALL events to S3 (archive)
# ============================================================

resource "aws_iot_topic_rule" "s3_archive_route" {
  name        = "${var.utility_name}-to-s3-archive"
  description = "Archive all telemetry data to S3 for long-term storage and Athena queries"
  enabled     = true
  sql         = "SELECT * FROM 'grid/telemetry/+'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = var.s3_archive_bucket
    key         = "raw/telemetry/${formatdate("YYYY/MM/DD", timestamp())}/${topic(3)}/${uuid()}.json"
    role_arn    = aws_iam_role.iot_s3.arn
  }

  tags = local.common_tags
}

# ============================================================
# IAM Roles for IoT Topic Rules
# ============================================================

resource "aws_iam_role" "iot_timestream" {
  name = "${var.utility_name}-iot-timestream-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot_timestream" {
  name = "${var.utility_name}-iot-timestream-policy"
  role = aws_iam_role.iot_timestream.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "timestream:WriteRecords",
        "timestream:DescribeEndpoints"
      ]
      Resource = [
        "arn:aws:timestream:${var.region}:*:database/${var.timestream_database_name}",
        "arn:aws:timestream:${var.region}:*:database/${var.timestream_database_name}/table/${var.timestream_table_name}"
      ]
    }]
  })
}

resource "aws_iam_role" "iot_kinesis" {
  name = "${var.utility_name}-iot-kinesis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot_kinesis" {
  name = "${var.utility_name}-iot-kinesis-policy"
  role = aws_iam_role.iot_kinesis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:DescribeStream"
      ]
      Resource = ["arn:aws:kinesis:${var.region}:*:stream/${var.kinesis_stream_name}"]
    }]
  })
}

resource "aws_iam_role" "iot_s3" {
  name = "${var.utility_name}-iot-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot_s3" {
  name = "${var.utility_name}-iot-s3-policy"
  role = aws_iam_role.iot_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject"
      ]
      Resource = ["arn:aws:s3:::${var.s3_archive_bucket}/raw/telemetry/*"]
    }]
  })
}

# ============================================================
# Device Defender — Detect compromised smart meters
# ============================================================

resource "aws_iot_device_defender_audit_subscription" "gridforge" {
  count = var.enable_device_defender ? 1 : 0

  # Enable all relevant audit checks for smart meter security
}

resource "aws_iot_security_profile" "meter_anomaly" {
  count = var.enable_device_defender ? 1 : 0

  name = "${var.utility_name}-meter-anomaly-profile"
  description = "Security profile detecting anomalous smart meter behavior"

  metric {
    name   = "aws:message-byte-in"
    criteria {
      comparison_operator = "greater-than"
      value = {
        count = 4096  # Alert if meter sends > 4KB per message
      }
      duration_seconds = 300
      consecutive_datapoints_to_alert = 3
    }
  }

  metric {
    name   = "aws:all-byte-out"
    criteria {
      comparison_operator = "less-than"
      value = {
        count = 1  # Alert if meter receives no data (potentially offline)
      }
      duration_seconds = 3600
      consecutive_datapoints_to_alert = 5
    }
  }

  metric {
    name   = "aws:num-connection-attempts"
    criteria {
      comparison_operator = "greater-than"
      value = {
        count = 100  # Alert if > 100 connection attempts per minute (DDoS indicator)
      }
      duration_seconds = 60
      consecutive_datapoints_to_alert = 2
    }
  }

  tags = local.common_tags
}

# ============================================================
# Greengrass v2 — Edge Computing at Substations
# ============================================================

resource "aws_greengrassv2_component" "edge_anomaly_detector" {
  count = var.enable_greengrass ? 1 : 0

  name    = "${var.utility_name}-edge-anomaly-detector"
  version = "1.0.0"

  lifecycle {
    ignore_changes = [version]
  }
}

resource "aws_greengrassv2_deployment" "edge_gateways" {
  count = var.enable_greengrass ? 1 : 0

  target_arn = aws_iot_thing_group.meters.arn

  components = {
    "aws.greengrass.Cli" = {
      version = "2.12.0"
    }
    "aws.greengrass.Nucleus" = {
      version = "2.12.0"
    }
    "aws.greengrass.LocalDebugConsole" = {
      version = "2.3.0"
    }
  }

  deployment_policies {
    failure_handling_policy = "DO_NOTHING"
    component_update_policy {
      action = "NOTIFY_COMPONENTS"
      timeout = 60
    }
    configuration_validation_policy {
      timeout = 60
    }
  }

  tags = local.common_tags
}

# ============================================================
# ACM Private CA — Device certificate management
# ============================================================

resource "aws_acmpca_certificate_authority" "iot_ca" {
  permanent_deletion_days = 30
  type                    = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name = "${var.utility_name}-IoT-CA"
      country     = "ZA"
      organization = var.utility_name
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-iot-ca"
  })
}

# ============================================================
# Locals
# ============================================================

locals {
  common_tags = {
    Project     = "GridForge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Utility     = var.utility_name
  }

  region = var.region
}
