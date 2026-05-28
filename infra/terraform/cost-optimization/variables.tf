# GridForge — Cost Optimization Module Variables

variable "utility_name" { description = "Utility company name"; type = string }
variable "environment" { description = "Deployment environment"; type = string; default = "production" }
variable "region" { description = "AWS region"; type = string; default = "af-south-1" }
variable "budget_limit" { description = "Monthly budget limit (USD)"; type = number; default = 1000 }
variable "budget_alert_emails" { description = "Email addresses for budget alerts"; type = list(string); default = [] }
variable "enable_spot_recommendations" { description = "Include Spot instance recommendations"; type = bool; default = true }
variable "cost_monitor_source_dir" { description = "Path to cost monitor Lambda source"; type = string }
variable "lambda_architecture" { description = "Lambda CPU architecture"; type = string; default = "arm64" }
variable "lambda_kms_key_arn" { description = "KMS key ARN for Lambda encryption"; type = string }
variable "sns_topic_arns" { description = "SNS topic ARNs"; type = map(string) }
