# GridForge — IoT Ingestion Module Outputs

output "iot_endpoint" {
  description = "IoT Core endpoint for device connections"
  value       = data.aws_iot_endpoint.main.endpoint_address
}

output "thing_group_name" {
  description = "IoT Thing Group name"
  value       = aws_iot_thing_group.meters.name
}

output "thing_group_arn" {
  description = "IoT Thing Group ARN"
  value       = aws_iot_thing_group.meters.arn
}

output "greengrass_deployment_id" {
  description = "Greengrass deployment ID"
  value       = try(aws_greengrassv2_deployment.edge_gateways[0].id, null)
}

output "meter_policy_name" {
  description = "IoT policy name for smart meters"
  value       = aws_iot_policy.meter_policy.name
}

output "certificate_authority_arn" {
  description = "ACM Private CA ARN for device certificates"
  value       = aws_acmpca_certificate_authority.iot_ca.arn
}

data "aws_iot_endpoint" "main" {
  endpoint_type = "iot:Data-ATS"
}
