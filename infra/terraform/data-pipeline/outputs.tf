# GridForge — Data Pipeline Module Outputs

output "kinesis_stream_name" {
  description = "Kinesis Data Stream name"
  value       = try(aws_kinesis_stream.telemetry[0].name, "")
}

output "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN"
  value       = try(aws_kinesis_stream.telemetry[0].arn, "")
}

output "timestream_database_name" {
  description = "Timestream database name"
  value       = aws_timestreamwrite_database.grid_telemetry.database_name
}

output "timestream_database_arn" {
  description = "Timestream database ARN"
  value       = aws_timestreamwrite_database.grid_telemetry.arn
}

output "timestream_table_name" {
  description = "Timestream table name"
  value       = aws_timestreamwrite_table.meter_readings.table_name
}

output "s3_data_lake_bucket" {
  description = "S3 data lake bucket name"
  value       = aws_s3_bucket.data_lake.bucket
}

output "s3_data_lake_arn" {
  description = "S3 data lake bucket ARN"
  value       = aws_s3_bucket.data_lake.arn
}

output "dynamodb_table_arn" {
  description = "DynamoDB incidents table ARN"
  value       = aws_dynamodb_table.incidents.arn
}

output "eventbridge_bus_arn" {
  description = "EventBridge custom event bus ARN"
  value       = aws_cloudwatch_event_bus.gridforge.arn
}

output "glue_database_name" {
  description = "Glue catalog database name"
  value       = aws_glue_catalog_database.gridforge.name
}
