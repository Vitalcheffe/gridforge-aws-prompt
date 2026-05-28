# GridForge — Networking Module Variables

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for subnet deployment"
  type        = list(string)
  default     = ["af-south-1a", "af-south-1b", "af-south-1c"]
}

variable "utility_name" {
  description = "Utility company name for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "af-south-1"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateways for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost savings (recommended for < 5000 meters)"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway for on-premise SCADA connectivity"
  type        = bool
  default     = false
}

variable "vpc_endpoints" {
  description = "Map of VPC endpoints to create (key=service, value=type Gateway|Interface)"
  type        = map(string)
  default     = {}
}
