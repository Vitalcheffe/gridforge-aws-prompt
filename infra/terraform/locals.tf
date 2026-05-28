# GridForge — Local Values

locals {
  name_prefix = "${var.project_name}-${var.utility_name}-${var.environment}"

  common_tags = merge(var.common_tags, {
    Project     = "GridForge"
    Environment = var.environment
    Utility     = var.utility_name
    ManagedBy   = "terraform"
  })

  # Calculate Kinesis shard count based on meter count
  # Each shard supports ~1,000 records/sec
  # Average: 1 reading per meter per 5 seconds = meter_count/5000 records/sec
  calculated_shard_count = max(1, ceil(var.meter_count / 5000))

  # Calculate Timestream memory store retention based on environment
  # Production: 24h, Staging: 12h, Dev: 6h
  memory_retention_map = {
    production = 24
    staging    = 12
    dev        = 6
  }

  effective_memory_retention = lookup(local.memory_retention_map, var.environment, 24)

  # af-south-1 service availability
  # Some services have limited availability in Cape Town
  af_south_1_services = {
    iot_core       = true
    greengrass     = true
    kinesis        = true
    timestream     = true
    bedrock        = true
    sagemaker      = true
    lambda         = true
    step_functions = true
    quicksight     = true
    guardduty      = true
    security_hub   = true
    config         = true
    cloudtrail     = true
    transit_gateway = true
  }
}
