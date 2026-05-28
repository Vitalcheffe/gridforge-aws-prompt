# GridForge — Data Pipeline Module
# Kinesis Data Streams, Firehose, Timestream, S3 Data Lake, Glue Crawler, EventBridge
# Handles real-time telemetry streaming and historical data storage

# ============================================================
# Kinesis Data Streams — Real-time telemetry streaming
# On-demand mode auto-scales; provisioned mode for predictable workloads
# ============================================================

resource "aws_kinesis_stream" "telemetry" {
  count = var.enable_kinesis ? 1 : 0

  name             = var.kinesis_stream_name
  retention_period = 24  # Hours — data available for 24h for replay

  # On-demand mode for variable smart meter traffic patterns
  stream_mode_details {
    stream_mode = var.kinesis_mode
  }

  # Provisioned mode configuration (only used when kinesis_mode = PROVISIONED)
  shard_count = var.kinesis_mode == "PROVISIONED" ? var.kinesis_shard_count : null

  # Enhanced fan-out for Lambda consumers — dedicated 2MB/sec per consumer
  # No throttling from other consumers reading the same stream
  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-kinesis-telemetry"
  })
}

# ============================================================
# Kinesis Data Firehose — Buffer + Parquet conversion to S3
# Delivers telemetry to S3 in Parquet format for Athena queries
# ============================================================

resource "aws_kinesis_firehose_delivery_stream" "telemetry_to_s3" {
  count       = var.enable_firehose ? 1 : 0
  name        = "${var.utility_name}-telemetry-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.telemetry[0].arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.data_lake.arn
    buffering_size      = 128  # MB — batch before writing to S3
    buffering_interval  = 300  # Seconds — max wait time
    compression_format  = "UNCOMPRESSED"

    # Parquet conversion for efficient Athena queries
    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {
            compression = "SNAPPY"
          }
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.gridforge.name
        table_name    = aws_glue_catalog_table.telemetry.name
        role_arn      = aws_iam_role.firehose.arn
        region        = var.region
      }
    }

    # Partition by date/region/meter_type for efficient queries
    prefix              = "curated/telemetry/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/telemetry/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = "delivery-errors"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-firehose-telemetry"
  })
}

# ============================================================
# Amazon Timestream — Time-series telemetry storage
# Tiered storage: memory (hot) + magnetic (cold)
# ============================================================

resource "aws_timestreamwrite_database" "grid_telemetry" {
  database_name = var.timestream_database_name
  kms_key_id    = var.timestream_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-timestream-db"
  })
}

resource "aws_timestreamwrite_table" "meter_readings" {
  database_name = aws_timestreamwrite_database.grid_telemetry.database_name
  table_name    = var.timestream_table_name

  # Memory store: hot data for real-time dashboards (default 24h)
  # Magnetic store: cold data for historical analysis (default 365d)
  retention_properties {
    magnetic_store_retention_period_in_days = var.timestream_magnetic_retention
    memory_store_retention_period_in_hours  = var.timestream_memory_retention
  }

  # Enable magnetic store writes for late-arriving data from offline meters
  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-timestream-meter-readings"
  })
}

# ============================================================
# S3 Data Lake — Long-term storage, Athena queries, Glue catalog
# ============================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = var.data_lake_bucket_name

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-data-lake"
  })
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.s3_kms_key_arn
    }
    bucket_key_enabled = true  # Reduce KMS API costs by 95%
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "glacier-archive"
    status = "Enabled"

    filter {
      prefix = "raw/telemetry/"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# S3 bucket policy — require TLS for all access
resource "aws_s3_bucket_policy" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================
# AWS Glue — Schema discovery and Athena integration
# ============================================================

resource "aws_glue_catalog_database" "gridforge" {
  name = "${replace(lower(var.utility_name), "-", "_")}_gridforge_datalake"
}

resource "aws_glue_catalog_table" "telemetry" {
  name          = "telemetry"
  database_name = aws_glue_catalog_database.gridforge.name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/curated/telemetry/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    columns {
      name = "meter_id"
      type = "string"
    }
    columns {
      name = "voltage"
      type = "double"
    }
    columns {
      name = "current"
      type = "double"
    }
    columns {
      name = "frequency"
      type = "double"
    }
    columns {
      name = "power_factor"
      type = "double"
    }
    columns {
      name = "substation_id"
      type = "string"
    }
    columns {
      name = "region"
      type = "string"
    }
    columns {
      name = "meter_type"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "timestamp"
    }

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
}

resource "aws_glue_crawler" "telemetry" {
  count = var.enable_glue_crawler ? 1 : 0

  name          = "${var.utility_name}-telemetry-crawler"
  database_name = aws_glue_catalog_database.gridforge.name
  schedule      = var.glue_crawler_schedule

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/curated/telemetry/"
  }

  role = aws_iam_role.glue.arn

  tags = local.common_tags
}

# ============================================================
# Amazon EventBridge — Event routing for anomaly orchestration
# ============================================================

resource "aws_cloudwatch_event_bus" "gridforge" {
  name = "${var.utility_name}-grid-events"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-event-bus"
  })
}

resource "aws_cloudwatch_event_rule" "anomaly_critical" {
  name           = "${var.utility_name}-anomaly-critical"
  description    = "Route critical grid anomaly events to Step Functions"
  event_bus_name = aws_cloudwatch_event_bus.gridforge.name

  event_pattern = jsonencode({
    source      = ["gridforge.anomaly-detector"]
    detail-type = ["Grid Anomaly"]
    detail = {
      severity = ["HIGH", "CRITICAL"]
    }
  })

  tags = local.common_tags
}

# ============================================================
# DynamoDB — Incident audit trail
# ============================================================

resource "aws_dynamodb_table" "incidents" {
  name         = "${var.utility_name}-grid-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"
  range_key    = "timestamp"

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  # GSI for querying by severity
  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-incidents-table"
  })
}

# ============================================================
# IAM Roles
# ============================================================

resource "aws_iam_role" "firehose" {
  name = "${var.utility_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.utility_name}-firehose-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords"]
        Resource = [aws_kinesis_stream.telemetry[0].arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:PutObject"]
        Resource = [aws_s3_bucket.data_lake.arn, "${aws_s3_bucket.data_lake.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.region}:*:log-group:/aws/firehose/*"]
      },
      {
        Effect = "Allow"
        Action = ["glue:GetTable", "glue:GetTableVersion", "glue:GetTableVersions"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "glue" {
  name = "${var.utility_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "glue" {
  name = "${var.utility_name}-glue-policy"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.data_lake.arn, "${aws_s3_bucket.data_lake.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.region}:*:*"]
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/firehose/${var.utility_name}-telemetry"
  retention_in_days = 30

  tags = local.common_tags
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
}
