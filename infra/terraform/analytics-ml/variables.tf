# GridForge — Analytics & ML Module Variables

variable "utility_name" { description = "Utility company name"; type = string }
variable "environment" { description = "Deployment environment"; type = string; default = "production" }
variable "region" { description = "AWS region"; type = string; default = "af-south-1" }
variable "meter_count" { description = "Number of smart meters"; type = number }
variable "enable_bedrock" { description = "Enable Bedrock Claude 3.5 for grid analysis"; type = bool; default = true }
variable "enable_sagemaker" { description = "Deploy SageMaker Serverless for ML inference"; type = bool; default = true }
variable "sagemaker_model_name" { description = "SageMaker model name for predictive maintenance"; type = string; default = "xgboost-grid-health-v1" }
variable "sagemaker_endpoint_name" { description = "SageMaker endpoint name"; type = string; default = "" }
variable "lambda_architecture" { description = "Lambda CPU architecture (arm64 or x86_64)"; type = string; default = "arm64" }

variable "anomaly_detector_source_dir" { description = "Path to anomaly detector Lambda source"; type = string }
variable "grid_event_processor_source_dir" { description = "Path to grid event processor Lambda source"; type = string }
variable "data_attestation_source_dir" { description = "Path to data attestation Lambda source"; type = string }

variable "kinesis_stream_arn" { description = "Kinesis Data Stream ARN"; type = string }
variable "kinesis_stream_name" { description = "Kinesis Data Stream name"; type = string }
variable "sns_topic_arns" { description = "SNS topic ARNs map"; type = map(string) }
variable "eventbridge_bus_arn" { description = "EventBridge custom bus ARN"; type = string }
variable "iot_endpoint" { description = "IoT Core endpoint"; type = string }
variable "dynamodb_table_arn" { description = "DynamoDB incidents table ARN"; type = string }
variable "lambda_kms_key_arn" { description = "KMS key ARN for Lambda encryption"; type = string }
variable "anomaly_detector_concurrency" { description = "Provisioned concurrency for anomaly detector"; type = number; default = 0 }
variable "anomaly_detector_memory" { description = "Memory for anomaly detector Lambda (MB)"; type = number; default = 512 }
variable "enable_kinesis" { description = "Whether Kinesis is enabled"; type = bool; default = true }

variable "private_subnet_ids" { description = "Private subnet IDs for Lambda VPC"; type = list(string); default = [] }
variable "lambda_security_group_id" { description = "Security group ID for Lambda"; type = string; default = "" }
