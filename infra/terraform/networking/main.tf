# GridForge — Networking Module
# VPC, Subnets, Security Groups, VPC Endpoints, Transit Gateway

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "gridforge" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ============================================================
# Subnets — 3 tiers per AZ
# ============================================================

# Public subnets — ALB, NAT Gateway
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.gridforge.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# Private subnets — ECS, Lambda, SageMaker
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.gridforge.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

# Isolated subnets — Databases (Timestream, DynamoDB) — no internet
resource "aws_subnet" "isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.gridforge.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-isolated-${count.index + 1}"
    Tier = "isolated"
  })
}

# ============================================================
# Internet Gateway
# ============================================================

resource "aws_internet_gateway" "gridforge" {
  vpc_id = aws_vpc.gridforge.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ============================================================
# NAT Gateways — One per AZ for high availability
# ============================================================

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "gridforge" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.gridforge]
}

# ============================================================
# Route Tables
# ============================================================

# Public route table — direct internet access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.gridforge.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gridforge.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables — NAT Gateway for outbound
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.gridforge.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gridforge[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-private-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Isolated route table — no internet, VPC endpoints only
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.gridforge.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-isolated"
  })
}

resource "aws_route_table_association" "isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# ============================================================
# VPC Endpoints — Private connectivity to AWS services
# ============================================================

# S3 Gateway Endpoint — no charge
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.gridforge.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = concat(
    [aws_route_table.private[0].id, aws_route_table.private[1].id, aws_route_table.private[2].id],
    [aws_route_table.isolated.id]
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-s3"
  })
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.gridforge.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  route_table_ids = concat(
    [aws_route_table.private[0].id, aws_route_table.private[1].id, aws_route_table.private[2].id],
    [aws_route_table.isolated.id]
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-dynamodb"
  })
}

# Interface Endpoints — for services that need private DNS
locals {
  interface_endpoints = [
    "com.amazonaws.${var.aws_region}.ecr.api",
    "com.amazonaws.${var.aws_region}.ecr.dkr",
    "com.amazonaws.${var.aws_region}.logs",
    "com.amazonaws.${var.aws_region}.iot.data",
    "com.amazonaws.${var.aws_region}.states",
    "com.amazonaws.${var.aws_region}.bedrock-agent-runtime",
    "com.amazonaws.${var.aws_region}.kinesis-firehose",
    "com.amazonaws.${var.aws_region}.sns",
    "com.amazonaws.${var.aws_region}.sqs",
  ]
}

resource "aws_vpc_endpoint" "interface" {
  count               = length(local.interface_endpoints)
  vpc_id              = aws_vpc.gridforge.id
  service_name        = local.interface_endpoints[count.index]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-${split(".", local.interface_endpoints[count.index])[3]}"
  })
}

# ============================================================
# Security Groups
# ============================================================

# VPC Endpoints security group
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpce-"
  vpc_id      = aws_vpc.gridforge.id
  description = "Security group for VPC interface endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-vpce"
  })
}

# IoT Greengrass security group
resource "aws_security_group" "greengrass" {
  name_prefix = "${local.name_prefix}-greengrass-"
  vpc_id      = aws_vpc.gridforge.id
  description = "Security group for Greengrass edge gateways"

  ingress {
    description     = "MQTT from IoT Core"
    from_port       = 8883
    to_port         = 8883
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-greengrass"
  })
}

# Lambda security group
resource "aws_security_group" "lambda" {
  name_prefix = "${local.name_prefix}-lambda-"
  vpc_id      = aws_vpc.gridforge.id
  description = "Security group for Lambda functions (anomaly detection, event processing)"

  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-lambda"
  })
}

# ============================================================
# Transit Gateway — Hybrid connectivity to on-premise SCADA
# ============================================================

resource "aws_ec2_transit_gateway" "gridforge" {
  description                     = "GridForge Transit Gateway for hybrid SCADA connectivity"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  amazon_side_asn                 = 64512

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "gridforge" {
  transit_gateway_id = aws_ec2_transit_gateway.gridforge.id
  vpc_id             = aws_vpc.gridforge.id
  subnet_ids         = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw-attachment"
  })
}

# Network ACL for isolated subnets — deny all inbound
resource "aws_network_acl" "isolated" {
  vpc_id     = aws_vpc.gridforge.id
  subnet_ids = aws_subnet.isolated[*].id

  # Allow only outbound HTTPS to private subnets
  egress {
    rule_no    = 100
    action     = "allow"
    from_port  = 443
    to_port    = 443
    protocol   = "tcp"
    cidr_block = "10.0.0.0/16"
  }

  # Deny all other outbound
  egress {
    rule_no    = 200
    action     = "deny"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nacl-isolated"
  })
}
