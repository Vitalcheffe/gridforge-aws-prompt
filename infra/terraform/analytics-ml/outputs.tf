# GridForge — Analytics & ML Module Outputs

output "anomaly_detector_lambda_arn" {
  description = "Anomaly detector Lambda ARN"
  value       = aws_lambda_function.anomaly_detector.arn
}

output "anomaly_detector_lambda_name" {
  description = "Anomaly detector Lambda function name"
  value       = aws_lambda_function.anomaly_detector.function_name
}

output "grid_event_processor_lambda_arn" {
  description = "Grid event processor Lambda ARN"
  value       = aws_lambda_function.grid_event_processor.arn
}

output "data_attestation_lambda_arn" {
  description = "Data attestation Lambda ARN"
  value       = aws_lambda_function.data_attestation.arn
}

output "step_functions_state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.grid_response.arn
}

output "step_functions_execution_role_arn" {
  description = "Step Functions execution IAM role ARN"
  value       = aws_iam_role.step_functions.arn
}

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name (if enabled)"
  value       = try(aws_sagemaker_endpoint.grid_health[0].name, "")
}
