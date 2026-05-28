# GridForge — Dashboards & Monitoring Module Variables

variable "utility_name" { description = "Utility company name"; type = string }
variable "environment" { description = "Deployment environment"; type = string; default = "production" }
variable "region" { description = "AWS region"; type = string; default = "af-south-1" }
variable "meter_count" { description = "Number of smart meters"; type = number }
variable "enable_quicksight" { description = "Deploy QuickSight dashboard"; type = bool; default = true }
variable "quicksight_reader_count" { description = "QuickSight reader seats"; type = number; default = 5 }
variable "alert_email" { description = "Email for alerts"; type = string; default = "" }
variable "iot_message_rate_threshold" { description = "IoT message rate alarm threshold (msg/min)"; type = number; default = 1000 }
variable "lambda_error_rate_threshold" { description = "Lambda error rate alarm threshold (%)"; type = number; default = 5 }
variable "kinesis_iterator_age_threshold" { description = "Kinesis iterator age alarm threshold (ms)"; type = number; default = 60000 }
variable "monthly_cost_threshold" { description = "Monthly cost alarm threshold (USD)"; type = number; default = 1000 }
variable "timestream_database_name" { description = "Timestream database name for QuickSight"; type = string }
variable "timestream_table_name" { description = "Timestream table name for QuickSight"; type = string }
