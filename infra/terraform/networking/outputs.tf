# GridForge — Networking Module Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.gridforge.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.gridforge.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs"
  value       = aws_subnet.isolated[*].id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID (if VPN enabled)"
  value       = try(aws_ec2_transit_gateway.gridforge[0].id, null)
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}
