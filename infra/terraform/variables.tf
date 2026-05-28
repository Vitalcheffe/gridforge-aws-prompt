# GridForge — Variables
# AWS Smart Grid Infrastructure Deployer for Emerging Markets

# ============================================================
# General
# ============================================================

variable "aws_region" {
  description = "AWS region for deployment. af-south-1 (Cape Town) recommended for African utilities."
  type        = string
  default     = "af-south-1"
}

variable "environment" {
  description = "Deployment environment: dev, staging, or production."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "utility_name" {
  description = "Name of the utility company (e.g., Volta River Authority, Eko Electricity). Used for resource naming and tagging."
  type        = string
}

variable "project_name" {
  description = "Project identifier used for resource naming."
  type        = string
  default     = "gridforge"
}

# ============================================================
# Networking
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 provides 65,536 addresses across all subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones in af-south-1 for high availability. Minimum 3 for production."
  type        = list(string)
  default     = ["af-south-1a", "af-south-1b", "af-south-1c"]
}

# ============================================================
# IoT & Meters
# ============================================================

variable "meter_count" {
  description = "Estimated number of smart meters to be connected. Affects IoT Core provisioning and Kinesis shard count."
  type        = number
  default     = 10000

  validation {
    condition     = var.meter_count >= 100 && var.meter_count <= 100000
    error_message = "Meter count must be between 100 and 100,000."
  }
}

variable "sensor_count" {
  description = "Number of grid sensors (voltage, current, frequency monitors) at substations."
  type        = number
  default     = 500
}

# ============================================================
# Data Pipeline
# ============================================================

variable "retention_days" {
  description = "Number of days to retain telemetry data in Timestream magnetic store. Longer retention = higher cost."
  type        = number
  default     = 365

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 3650
    error_message = "Retention must be between 30 and 3650 days."
  }
}

variable "memory_store_retention_hours" {
  description = "Hours to keep data in Timestream memory store for fast queries. 24h default balances cost and query speed."
  type        = number
  default     = 24
}

variable "kinesis_shard_count" {
  description = "Number of Kinesis shards. Each shard supports 1,000 records/sec. Auto-calculated if using on-demand mode."
  type        = number
  default     = 2
}

variable "kinesis_mode" {
  description = "Kinesis capacity mode: ON_DEMAND (auto-scales, recommended) or PROVISIONED (fixed shards, lower cost for predictable traffic)."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "PROVISIONED"], var.kinesis_mode)
    error_message = "Kinesis mode must be ON_DEMAND or PROVISIONED."
  }
}

# ============================================================
# Analytics & ML
# ============================================================

variable "sagemaker_instance_type" {
  description = "SageMaker endpoint instance type. ml.c5.xlarge for real-time, serverless for low-traffic."
  type        = string
  default     = "ml.c5.xlarge"
}

variable "sagemaker_serverless" {
  description = "Use SageMaker Serverless Inference for cost optimization. Recommended for <1000 invocations/day."
  type        = bool
  default     = true
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID for natural language grid analysis."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

# ============================================================
# Security
# ============================================================

variable "kms_key_rotation_days" {
  description = "Number of days between KMS key auto-rotation. 90 days meets most compliance frameworks."
  type        = number
  default     = 90
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection. Recommended for all production deployments."
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub with NERC CIP standards."
  type        = bool
  default     = true
}

# ============================================================
# Cost Optimization
# ============================================================

variable "monthly_budget" {
  description = "Monthly AWS budget in USD. Budget alert triggers at 80% and 100%."
  type        = number
  default     = 500

  validation {
    condition     = var.monthly_budget >= 50 && var.monthly_budget <= 50000
    error_message = "Monthly budget must be between $50 and $50,000."
  }
}

variable "use_spot_instances" {
  description = "Use FARGATE_SPOT for batch analytics workloads. 70% cost savings, acceptable for non-critical processing."
  type        = bool
  default     = true
}

variable "lambda_architecture" {
  description = "Lambda architecture: arm64 (Graviton, 20% better price-performance) or x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "Architecture must be arm64 or x86_64."
  }
}

# ============================================================
# Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to all resources for cost tracking and governance."
  type        = map(string)
  default     = {}
}
