# GridForge — Data Pipeline Module Variables

variable "utility_name" { description = "Utility company name"; type = string }
variable "environment" { description = "Deployment environment"; type = string; default = "production" }
variable "region" { description = "AWS region"; type = string; default = "af-south-1" }
variable "meter_count" { description = "Number of smart meters"; type = number }

variable "enable_kinesis" { description = "Deploy Kinesis Data Streams"; type = bool; default = true }
variable "kinesis_mode" { description = "Kinesis capacity mode (ON_DEMAND or PROVISIONED)"; type = string; default = "ON_DEMAND" }
variable "kinesis_stream_name" { description = "Kinesis stream name"; type = string; default = "gridforge-telemetry" }
variable "kinesis_shard_count" { description = "Kinesis shard count (provisioned mode)"; type = number; default = 2 }
variable "enable_firehose" { description = "Deploy Kinesis Firehose for S3 delivery"; type = bool; default = true }

variable "timestream_database_name" { description = "Timestream database name"; type = string; default = "grid-telemetry" }
variable "timestream_table_name" { description = "Timestream table name"; type = string; default = "meter-readings" }
variable "timestream_memory_retention" { description = "Timestream memory store retention (hours)"; type = number; default = 24 }
variable "timestream_magnetic_retention" { description = "Timestream magnetic store retention (days)"; type = number; default = 365 }
variable "timestream_kms_key_arn" { description = "KMS key ARN for Timestream encryption"; type = string }

variable "data_lake_bucket_name" { description = "S3 data lake bucket name"; type = string }
variable "s3_kms_key_arn" { description = "KMS key ARN for S3 encryption"; type = string }
variable "enable_glue_crawler" { description = "Enable Glue Crawler for schema discovery"; type = bool; default = true }
variable "glue_crawler_schedule" { description = "Glue Crawler schedule expression"; type = string; default = "cron(0 2 * * ? *)" }
