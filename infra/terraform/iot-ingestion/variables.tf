# GridForge — IoT Ingestion Module Variables

variable "utility_name" {
  description = "Utility company name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "af-south-1"
}

variable "meter_count" {
  description = "Number of smart meters"
  type        = number
}

variable "thing_group_name" {
  description = "IoT Thing Group name for smart meters"
  type        = string
}

variable "enable_greengrass" {
  description = "Deploy Greengrass edge gateways"
  type        = bool
  default     = true
}

variable "greengrass_gateways" {
  description = "Number of Greengrass edge gateways"
  type        = number
  default     = 500
}

variable "enable_device_defender" {
  description = "Enable IoT Device Defender"
  type        = bool
  default     = true
}

variable "iot_kms_key_arn" {
  description = "KMS key ARN for IoT data encryption"
  type        = string
}

variable "voltage_low_threshold" {
  description = "Low voltage anomaly threshold (volts)"
  type        = number
  default     = 180
}

variable "voltage_high_threshold" {
  description = "High voltage anomaly threshold (volts)"
  type        = number
  default     = 260
}

variable "frequency_deviation" {
  description = "Frequency deviation threshold (Hz from 50Hz)"
  type        = number
  default     = 0.5
}

variable "timestream_database_name" {
  description = "Timestream database name for telemetry routing"
  type        = string
  default     = "grid-telemetry"
}

variable "timestream_table_name" {
  description = "Timestream table name for meter readings"
  type        = string
  default     = "meter-readings"
}

variable "kinesis_stream_name" {
  description = "Kinesis stream name for critical event routing"
  type        = string
  default     = "gridforge-telemetry"
}

variable "s3_archive_bucket" {
  description = "S3 bucket name for telemetry archive"
  type        = string
}
