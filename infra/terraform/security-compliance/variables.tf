# GridForge — Security & Compliance Module Variables

variable "utility_name" { description = "Utility company name"; type = string }
variable "environment" { description = "Deployment environment"; type = string; default = "production" }
variable "region" { description = "AWS region"; type = string; default = "af-south-1" }
variable "enable_guardduty" { description = "Enable GuardDuty threat detection"; type = bool; default = true }
variable "enable_security_hub" { description = "Enable Security Hub with NERC CIP"; type = bool; default = true }
variable "enable_config" { description = "Enable AWS Config Rules"; type = bool; default = true }
variable "kms_key_rotation_days" { description = "KMS key rotation period (days)"; type = number; default = 90 }

# Resource ARNs for IAM policy scoping
variable "kinesis_stream_arn" { description = "Kinesis stream ARN"; type = string; default = "" }
variable "timestream_db_arn" { description = "Timestream database ARN"; type = string; default = "" }
variable "s3_data_lake_arn" { description = "S3 data lake bucket ARN"; type = string; default = "" }
variable "sns_topic_arns" { description = "SNS topic ARNs"; type = map(string); default = {} }
variable "dynamodb_table_arn" { description = "DynamoDB table ARN"; type = string; default = "" }
variable "iot_thing_group_arn" { description = "IoT Thing Group ARN"; type = string; default = "" }
variable "eventbridge_bus_arn" { description = "EventBridge bus ARN"; type = string; default = "" }
