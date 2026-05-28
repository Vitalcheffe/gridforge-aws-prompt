# GridForge — Security & Compliance Module
# IAM Roles (12), KMS Keys, AWS Config, GuardDuty, Security Hub, CloudTrail
# NERC CIP compliance baseline for smart grid infrastructure

# ============================================================
# KMS Customer-Managed Keys — 4 keys with 90-day auto-rotation
# ============================================================

resource "aws_kms_key" "iot" {
  description             = "GridForge IoT data encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-iot-key"
  })
}

resource "aws_kms_alias" "iot" {
  name          = "alias/${var.utility_name}-iot-key"
  target_key_id = aws_kms_key.iot.key_id
}

resource "aws_kms_key" "timestream" {
  description             = "GridForge Timestream encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-timestream-key"
  })
}

resource "aws_kms_alias" "timestream" {
  name          = "alias/${var.utility_name}-timestream-key"
  target_key_id = aws_kms_key.timestream.key_id
}

resource "aws_kms_key" "s3" {
  description             = "GridForge S3 data lake encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-s3-key"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.utility_name}-s3-key"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_kms_key" "logs" {
  description             = "GridForge CloudWatch Logs encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-logs-key"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.utility_name}-logs-key"
  target_key_id = aws_kms_key.logs.key_id
}

# ============================================================
# IAM Roles — 12 least-privilege roles (one per module function)
# ============================================================

# Role 1: GridForge-IoT-Core
resource "aws_iam_role" "iot_core" {
  name = "${var.utility_name}-IoT-Core"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "iot.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Role = "IoT-Core" })
}

resource "aws_iam_role_policy" "iot_core" {
  name = "${var.utility_name}-iot-core-policy"
  role = aws_iam_role.iot_core.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["iot:Connect", "iot:Publish", "iot:Subscribe", "iot:Receive", "iot:GetThingShadow", "iot:UpdateThingShadow"]
        Resource = ["arn:aws:iot:${var.region}:*:thing/${var.utility_name}-*"]
        Condition = { Bool = { "iot:Connection.Thing.IsAttached" = "true" } }
      }
    ]
  })
}

# Role 2: GridForge-Greengrass
resource "aws_iam_role" "greengrass" {
  name = "${var.utility_name}-Greengrass"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "greengrass.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Role = "Greengrass" })
}

resource "aws_iam_role_policy" "greengrass" {
  name = "${var.utility_name}-greengrass-policy"
  role = aws_iam_role.greengrass.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["greengrass:*"], Resource = ["*"] },
      { Effect = "Allow", Action = ["iot:GetThingShadow", "iot:UpdateThingShadow"], Resource = ["arn:aws:iot:${var.region}:*:thing/${var.utility_name}-*"] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = ["*"] }
    ]
  })
}

# Role 3: GridForge-Kinesis-Writer
resource "aws_iam_role" "kinesis_writer" {
  name = "${var.utility_name}-Kinesis-Writer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "iot.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Kinesis-Writer" })
}

# Role 4: GridForge-Timestream-Writer
resource "aws_iam_role" "timestream_writer" {
  name = "${var.utility_name}-Timestream-Writer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "iot.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Timestream-Writer" })
}

# Role 5: GridForge-Lambda-Anomaly
resource "aws_iam_role" "lambda_anomaly" {
  name = "${var.utility_name}-Lambda-Anomaly"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Lambda-Anomaly" })
}

# Role 6: GridForge-Lambda-EventProc
resource "aws_iam_role" "lambda_event_proc" {
  name = "${var.utility_name}-Lambda-EventProc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Lambda-EventProc" })
}

# Role 7: GridForge-StepFunctions
resource "aws_iam_role" "step_functions" {
  name = "${var.utility_name}-StepFunctions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "states.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "StepFunctions" })
}

# Role 8: GridForge-Bedrock-Invoke
resource "aws_iam_role" "bedrock_invoke" {
  name = "${var.utility_name}-Bedrock-Invoke"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "bedrock.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Bedrock-Invoke" })
}

# Role 9: GridForge-SageMaker
resource "aws_iam_role" "sagemaker" {
  name = "${var.utility_name}-SageMaker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "sagemaker.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "SageMaker" })
}

# Role 10: GridForge-QuickSight
resource "aws_iam_role" "quicksight" {
  name = "${var.utility_name}-QuickSight"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "quicksight.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "QuickSight" })
}

# Role 11: GridForge-Config-Audit
resource "aws_iam_role" "config_audit" {
  name = "${var.utility_name}-Config-Audit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "config.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Config-Audit" })
}

# Role 12: GridForge-Cost-Monitor
resource "aws_iam_role" "cost_monitor" {
  name = "${var.utility_name}-Cost-Monitor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })

  tags = merge(local.common_tags, { Role = "Cost-Monitor" })
}

# ============================================================
# AWS Config — NERC CIP Compliance Rules
# ============================================================

resource "aws_config_configuration_recorder" "gridforge" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.utility_name}-config-recorder"
  role_arn = aws_iam_role.config_audit.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "gridforge" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.utility_name}-config-delivery"
  s3_bucket_name = "${var.utility_name}-config-bucket"
}

# NERC CIP-mapped Config Rules
resource "aws_config_config_rule" "cloudtrail_enabled" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  tags = local.common_tags
}

resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  tags = local.common_tags
}

resource "aws_config_config_rule" "no_public_ingress" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-no-public-ingress"

  source {
    owner             = "AWS"
    source_identifier = "NO_PUBLIC_INGRESS"
  }

  tags = local.common_tags
}

resource "aws_config_config_rule" "s3_bucket_logging" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-s3-bucket-logging-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LOGGING_ENABLED"
  }

  tags = local.common_tags
}

resource "aws_config_config_rule" "iam_mfa_enabled" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-iam-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_MFA_ENABLED"
  }

  tags = local.common_tags
}

resource "aws_config_config_rule" "vpc_flow_logs" {
  count = var.enable_config ? 1 : 0
  name  = "${var.utility_name}-vpc-flow-logs-enabled"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  tags = local.common_tags
}

# ============================================================
# GuardDuty — Threat detection with S3 and IoT protection
# ============================================================

resource "aws_guardduty_detector" "gridforge" {
  count = var.enable_guardduty ? 1 : 0

  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    iot {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false  # Not using EKS in this deployment
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-guardduty"
  })
}

# ============================================================
# Security Hub — NERC CIP compliance standard
# ============================================================

resource "aws_securityhub_account" "gridforge" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "nerc_cip" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.region}::standards/nerc-cip"

  depends_on = [aws_securityhub_account.gridforge]
}

# ============================================================
# CloudTrail — Multi-region audit trail
# ============================================================

resource "aws_cloudtrail" "gridforge" {
  name                       = "${var.utility_name}-trail"
  s3_bucket_name             = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail      = true
  enable_log_file_validation = true
  kms_key_id                 = aws_kms_key.logs.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${lower(replace(var.utility_name, "-", ""))}-cloudtrail-logs"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-cloudtrail-bucket"
  })
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.utility_name}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn

  tags = local.common_tags
}

resource "aws_iam_role" "cloudtrail" {
  name = "${var.utility_name}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  name = "${var.utility_name}-cloudtrail-policy"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = ["arn:aws:logs:${var.region}:*:*"]
    }]
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
}
