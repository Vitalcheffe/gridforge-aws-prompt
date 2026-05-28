# GridForge — Root Terraform Configuration
# AWS Smart Grid Infrastructure Deployer for Emerging Markets
# AWS Prompt the Planet Challenge 2026

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "gridforge-terraform-state"
    key            = "terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    dynamodb_table = "gridforge-terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "GridForge"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.utility_name
      CostCenter  = "grid-operations"
    }
  }
}

# Note: af-south-1 requires explicit opt-in for some accounts
# Ensure your AWS account has af-south-1 enabled before deploying

# ============================================================
# Module Calls
# ============================================================

module "networking" {
  source = "./networking"

  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  environment       = var.environment
  utility_name      = var.utility_name
}

module "iot_ingestion" {
  source = "./iot-ingestion"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  utility_name       = var.utility_name
  meter_count        = var.meter_count
  environment        = var.environment

  depends_on = [module.networking]
}

module "data_pipeline" {
  source = "./data-pipeline"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  utility_name       = var.utility_name
  environment        = var.environment
  retention_days     = var.retention_days

  iot_rule_role_arn = module.iot_ingestion.iot_rule_role_arn

  depends_on = [module.networking, module.iot_ingestion]
}

module "analytics_ml" {
  source = "./analytics-ml"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  utility_name       = var.utility_name
  environment        = var.environment

  kinesis_stream_arn = module.data_pipeline.kinesis_stream_arn
  timestream_db      = module.data_pipeline.timestream_database_name
  iot_endpoint       = module.iot_ingestion.iot_endpoint

  anomaly_detector_lambda_arn = module.analytics_ml.lambda_anomaly_detector_arn

  depends_on = [module.data_pipeline]
}

module "dashboards_monitoring" {
  source = "./dashboards-monitoring"

  utility_name = var.utility_name
  environment  = var.environment

  timestream_database = module.data_pipeline.timestream_database_name
  timestream_table    = module.data_pipeline.timestream_table_name

  depends_on = [module.data_pipeline]
}

module "security_compliance" {
  source = "./security-compliance"

  vpc_id        = module.networking.vpc_id
  utility_name  = var.utility_name
  environment   = var.environment

  # Pass all module role ARNs for CloudTrail auditing
  iot_role_arn        = module.iot_ingestion.iot_rule_role_arn
  lambda_role_arn     = module.analytics_ml.lambda_execution_role_arn
  step_functions_arn  = module.analytics_ml.step_functions_role_arn

  depends_on = [module.networking, module.iot_ingestion, module.data_pipeline, module.analytics_ml]
}

module "cost_optimization" {
  source = "./cost-optimization"

  utility_name  = var.utility_name
  environment   = var.environment
  monthly_budget = var.monthly_budget

  depends_on = [module.security_compliance]
}
