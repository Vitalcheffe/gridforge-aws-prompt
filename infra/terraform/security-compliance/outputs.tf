# GridForge — Security & Compliance Module Outputs

output "kms_key_arns" {
  description = "KMS CMK ARNs for data encryption"
  value = {
    "iot"         = aws_kms_key.iot.arn
    "timestream"  = aws_kms_key.timestream.arn
    "s3"          = aws_kms_key.s3.arn
    "logs"        = aws_kms_key.logs.arn
  }
}

output "cloudtrail_arn" {
  description = "CloudTrail multi-region trail ARN"
  value       = aws_cloudtrail.gridforge.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = try(aws_guardduty_detector.gridforge[0].id, "")
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = try(aws_securityhub_account.gridforge[0].arn, "")
}

output "iam_role_arns" {
  description = "All 12 IAM role ARNs"
  value = {
    "iot-core"          = aws_iam_role.iot_core.arn
    "greengrass"        = aws_iam_role.greengrass.arn
    "kinesis-writer"    = aws_iam_role.kinesis_writer.arn
    "timestream-writer" = aws_iam_role.timestream_writer.arn
    "lambda-anomaly"    = aws_iam_role.lambda_anomaly.arn
    "lambda-event-proc" = aws_iam_role.lambda_event_proc.arn
    "step-functions"    = aws_iam_role.step_functions.arn
    "bedrock-invoke"    = aws_iam_role.bedrock_invoke.arn
    "sagemaker"         = aws_iam_role.sagemaker.arn
    "quicksight"        = aws_iam_role.quicksight.arn
    "config-audit"      = aws_iam_role.config_audit.arn
    "cost-monitor"      = aws_iam_role.cost_monitor.arn
  }
}

output "config_rule_names" {
  description = "AWS Config rule names for NERC CIP compliance"
  value = var.enable_config ? [
    aws_config_config_rule.cloudtrail_enabled[0].name,
    aws_config_config_rule.encrypted_volumes[0].name,
    aws_config_config_rule.no_public_ingress[0].name,
    aws_config_config_rule.s3_bucket_logging[0].name,
    aws_config_config_rule.iam_mfa_enabled[0].name,
    aws_config_config_rule.vpc_flow_logs[0].name
  ] : []
}
