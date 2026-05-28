# GridForge — Outputs

# ============================================================
# Networking
# ============================================================

output "vpc_id" {
  description = "ID of the GridForge VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the GridForge VPC"
  value       = module.networking.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of private subnets for compute workloads"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets for ALB and NAT Gateway"
  value       = module.networking.public_subnet_ids
}

output "isolated_subnet_ids" {
  description = "IDs of isolated subnets for databases (no internet access)"
  value       = module.networking.isolated_subnet_ids
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway for hybrid SCADA connectivity"
  value       = module.networking.transit_gateway_id
}

# ============================================================
# IoT Ingestion
# ============================================================

output "iot_endpoint" {
  description = "AWS IoT Core endpoint for smart meter connections"
  value       = module.iot_ingestion.iot_endpoint
}

output "iot_thing_group_arn" {
  description = "ARN of the IoT Thing Group for smart meters"
  value       = module.iot_ingestion.thing_group_arn
}

output "greengrass_group_arn" {
  description = "ARN of the Greengrass Group for edge gateways"
  value       = module.iot_ingestion.greengrass_group_arn
}

# ============================================================
# Data Pipeline
# ============================================================

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis Data Stream for real-time telemetry"
  value       = module.data_pipeline.kinesis_stream_arn
}

output "timestream_database_name" {
  description = "Name of the Timestream database for grid telemetry"
  value       = module.data_pipeline.timestream_database_name
}

output "timestream_table_name" {
  description = "Name of the Timestream table for meter readings"
  value       = module.data_pipeline.timestream_table_name
}

output "s3_data_lake_bucket" {
  description = "Name of the S3 bucket for the telemetry data lake"
  value       = module.data_pipeline.s3_data_lake_bucket
}

# ============================================================
# Analytics & ML
# ============================================================

output "lambda_anomaly_detector_arn" {
  description = "ARN of the Lambda anomaly detection function"
  value       = module.analytics_ml.lambda_anomaly_detector_arn
}

output "sagemaker_endpoint_name" {
  description = "Name of the SageMaker predictive maintenance endpoint"
  value       = module.analytics_ml.sagemaker_endpoint_name
}

output "step_functions_state_machine_arn" {
  description = "ARN of the Step Functions grid response orchestrator"
  value       = module.analytics_ml.step_functions_state_machine_arn
}

# ============================================================
# Dashboards
# ============================================================

output "quicksight_dashboard_url" {
  description = "URL of the QuickSight Grid Operations Center dashboard"
  value       = module.dashboards_monitoring.quicksight_dashboard_url
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch infrastructure metrics dashboard"
  value       = module.dashboards_monitoring.cloudwatch_dashboard_url
}

# ============================================================
# Security
# ============================================================

output "kms_key_arn" {
  description = "ARN of the KMS Customer Managed Key for data encryption"
  value       = module.security_compliance.kms_key_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail multi-region trail"
  value       = module.security_compliance.cloudtrail_arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.security_compliance.guardduty_detector_id
}

output "security_hub_arn" {
  description = "ARN of the Security Hub with NERC CIP standards"
  value       = module.security_compliance.security_hub_arn
}

# ============================================================
# Cost Optimization
# ============================================================

output "budget_name" {
  description = "Name of the AWS Budget alert"
  value       = module.cost_optimization.budget_name
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost based on meter count and configuration"
  value       = module.cost_optimization.estimated_monthly_cost
}

# ============================================================
# Summary
# ============================================================

output "deployment_summary" {
  description = "Summary of the GridForge deployment"
  value = {
    region        = var.aws_region
    vpc_cidr      = var.vpc_cidr
    utility_name  = var.utility_name
    meter_count   = var.meter_count
    environment   = var.environment
    iot_endpoint  = module.iot_ingestion.iot_endpoint
    dashboard_url = module.dashboards_monitoring.quicksight_dashboard_url
  }
}
