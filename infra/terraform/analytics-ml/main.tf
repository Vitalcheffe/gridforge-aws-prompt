# GridForge — Analytics & ML Module
# Bedrock, SageMaker, Lambda Functions, Step Functions
# Handles anomaly detection, event processing, data attestation, and workflow orchestration

# ============================================================
# Lambda Function: Anomaly Detector
# Consumes Kinesis records, applies thresholds + ML scoring, publishes to SNS
# Architecture: arm64 (Graviton2) for 20% better price-performance
# ============================================================

data "archive_file" "anomaly_detector" {
  type        = "zip"
  source_dir  = var.anomaly_detector_source_dir
  output_path = "${path.module}/../lambda-packages/anomaly-detector.zip"
}

resource "aws_lambda_function" "anomaly_detector" {
  function_name = "${var.utility_name}-anomaly-detector"
  description   = "Detects grid anomalies from Kinesis telemetry stream using rule-based thresholds and ML scoring"
  role          = aws_iam_role.lambda_anomaly.arn
  handler       = "index.lambda_handler"

  filename         = data.archive_file.anomaly_detector.output_path
  source_code_hash = data.archive_file.anomaly_detector.output_base64sha256

  runtime     = "python3.11"
  architectures = [var.lambda_architecture]
  memory_size = var.anomaly_detector_memory
  timeout     = 60

  # Provisioned concurrency for production (eliminates cold starts)
  reserved_concurrent_executions = var.anomaly_detector_concurrency > 0 ? var.anomaly_detector_concurrency : null

  environment {
    variables = {
      SNS_TOPIC_ARN       = var.sns_topic_arns["critical-grid"]
      EVENTBRIDGE_BUS_ARN = var.eventbridge_bus_arn
      SAGEMAKER_ENDPOINT  = var.sagemaker_endpoint_name
      VOLTAGE_LOW         = "180"
      VOLTAGE_HIGH        = "260"
      FREQUENCY_DEVIATION = "0.5"
      POWER_FACTOR_LOW    = "0.85"
      LOG_LEVEL           = "INFO"
    }
  }

  # VPC configuration for private subnet
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  kms_key_arn = var.lambda_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-anomaly-detector"
  })
}

# Kinesis event source mapping for anomaly detector
resource "aws_lambda_event_source_mapping" "kinesis_anomaly" {
  count = var.enable_kinesis ? 1 : 0

  event_source_arn  = var.kinesis_stream_arn
  function_name     = aws_lambda_function.anomaly_detector.arn
  starting_position = "LATEST"
  batch_size        = 5
  maximum_batching_window_in_seconds = 5

  # Enhanced fan-out for dedicated throughput
  function_response_types = ["ReportBatchItemFailures"]
}

# ============================================================
# Lambda Function: Grid Event Processor
# Processes Step Functions events, classifies severity, sends notifications
# ============================================================

data "archive_file" "grid_event_processor" {
  type        = "zip"
  source_dir  = var.grid_event_processor_source_dir
  output_path = "${path.module}/../lambda-packages/grid-event-processor.zip"
}

resource "aws_lambda_function" "grid_event_processor" {
  function_name = "${var.utility_name}-grid-event-processor"
  description   = "Processes grid events from Step Functions, classifies severity, and sends notifications"
  role          = aws_iam_role.lambda_event_proc.arn
  handler       = "index.lambda_handler"

  filename         = data.archive_file.grid_event_processor.output_path
  source_code_hash = data.archive_file.grid_event_processor.output_base64sha256

  runtime     = "python3.11"
  architectures = [var.lambda_architecture]
  memory_size = 256
  timeout     = 30

  environment {
    variables = {
      DYNAMODB_TABLE    = "${var.utility_name}-grid-incidents"
      SNS_CRITICAL_ARN  = var.sns_topic_arns["critical-grid"]
      SNS_OPS_ARN       = var.sns_topic_arns["ops-alerts"]
      SES_SENDER        = "gridforge@${var.utility_name}.com"
      LOG_LEVEL         = "INFO"
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  kms_key_arn = var.lambda_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-grid-event-processor"
  })
}

# ============================================================
# Lambda Function: Data Attestation
# Hashes telemetry data, submits attestation record for integrity verification
# ============================================================

data "archive_file" "data_attestation" {
  type        = "zip"
  source_dir  = var.data_attestation_source_dir
  output_path = "${path.module}/../lambda-packages/data-attestation.zip"
}

resource "aws_lambda_function" "data_attestation" {
  function_name = "${var.utility_name}-data-attestation"
  description   = "Creates cryptographic hash attestations for telemetry data integrity verification"
  role          = aws_iam_role.lambda_attestation.arn
  handler       = "index.lambda_handler"

  filename         = data.archive_file.data_attestation.output_path
  source_code_hash = data.archive_file.data_attestation.output_base64sha256

  runtime     = "python3.11"
  architectures = [var.lambda_architecture]
  memory_size = 128
  timeout     = 15

  environment {
    variables = {
      ATTESTATION_TABLE = "${var.utility_name}-data-attestations"
      LOG_LEVEL         = "INFO"
    }
  }

  kms_key_arn = var.lambda_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-data-attestation"
  })
}

# ============================================================
# Step Functions: Grid Response Orchestrator
# Automated response workflow for grid anomalies
# ============================================================

resource "aws_sfn_state_machine" "grid_response" {
  name     = "${var.utility_name}-grid-response-orchestrator"
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile(
    "${path.module}/../data-pipeline/step-functions/state-machine.json",
    {
      region      = var.region
      account_id  = data.aws_caller_identity.current.account_id
      utility_name = var.utility_name
    }
  )

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-grid-response-orchestrator"
  })
}

# EventBridge target — invoke Step Functions on critical anomaly
resource "aws_cloudwatch_event_target" "step_functions" {
  rule           = "${var.utility_name}-anomaly-critical"
  event_bus_name = var.eventbridge_bus_arn
  target_id      = "StepFunctionsGridResponse"
  arn            = aws_sfn_state_machine.grid_response.arn
  role_arn       = aws_iam_role.eventbridge_step_functions.arn
}

# ============================================================
# Amazon Bedrock — Claude 3.5 Sonnet for grid analysis
# ============================================================

resource "aws_bedrockagent_agent" "grid_analyst" {
  count = var.enable_bedrock ? 1 : 0

  agent_name              = "${var.utility_name}-grid-analyst"
  agent_resource_role_arn = aws_iam_role.bedrock.arn
  description             = "AI grid analyst for natural language queries about grid operations and anomalies"
  foundation_model        = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  instruction = <<-EOT
    You are a grid operations analyst for ${var.utility_name}. You help operators understand grid anomalies,
    predict equipment failures, and recommend operational actions. Reference NERC CIP standards when discussing
    compliance. Always provide specific, actionable recommendations with confidence levels.
  EOT

  tags = local.common_tags
}

# ============================================================
# SageMaker Serverless — Predictive maintenance ML inference
# ============================================================

resource "aws_sagemaker_model" "grid_health" {
  count = var.enable_sagemaker ? 1 : 0

  name = "${var.utility_name}-${var.sagemaker_model_name}"

  execution_role_arn = aws_iam_role.sagemaker.arn

  containers {
    image = "174368400705.dkr.ecr.${var.region}.amazonaws.com/xgboost:latest"

    model_data_url = "s3://${var.utility_name}-ml-artifacts/model.tar.gz"

    environment = {
      SAGEMAKER_PROGRAM     = "inference.py"
      SAGEMAKER_SUBMIT_DIR  = "/opt/ml/model/code"
      SAGEMAKER_REGION      = var.region
    }
  }

  tags = local.common_tags
}

resource "aws_sagemaker_endpoint_configuration" "grid_health" {
  count = var.enable_sagemaker ? 1 : 0

  name = "${var.utility_name}-grid-health-endpoint-config"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.grid_health[0].name
    serverless_config {
      max_concurrency = 4
      memory_size_in_mb = 2048
    }
  }

  tags = local.common_tags
}

resource "aws_sagemaker_endpoint" "grid_health" {
  count = var.enable_sagemaker ? 1 : 0

  name                 = "${var.utility_name}-grid-health-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.grid_health[0].name

  tags = local.common_tags
}

# ============================================================
# IAM Roles — Least-privilege for each Lambda function
# ============================================================

resource "aws_iam_role" "lambda_anomaly" {
  name = "${var.utility_name}-lambda-anomaly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_anomaly" {
  name = "${var.utility_name}-lambda-anomaly-policy"
  role = aws_iam_role.lambda_anomaly.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:ListShards"]
        Resource = [var.kinesis_stream_arn]
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = [var.sns_topic_arns["critical-grid"]]
      },
      {
        Effect = "Allow"
        Action = ["events:PutEvents"]
        Resource = [var.eventbridge_bus_arn]
      },
      {
        Effect = "Allow"
        Action = ["sagemaker:InvokeEndpoint"]
        Resource = ["arn:aws:sagemaker:${var.region}:*:endpoint/${var.utility_name}-*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.region}:*:*"]
      }
    ]
  })
}

resource "aws_iam_role" "lambda_event_proc" {
  name = "${var.utility_name}-lambda-event-proc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_event_proc" {
  name = "${var.utility_name}-lambda-event-proc-policy"
  role = aws_iam_role.lambda_event_proc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:Query"], Resource = [var.dynamodb_table_arn] },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = [var.sns_topic_arns["ops-alerts"], var.sns_topic_arns["critical-grid"]] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = ["arn:aws:logs:${var.region}:*:*"] }
    ]
  })
}

resource "aws_iam_role" "lambda_attestation" {
  name = "${var.utility_name}-lambda-attestation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role" "step_functions" {
  name = "${var.utility_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "states.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.utility_name}-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [aws_lambda_function.grid_event_processor.arn] },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = [var.sns_topic_arns["critical-grid"]] },
      { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = [var.dynamodb_table_arn] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = ["*"] }
    ]
  })
}

resource "aws_iam_role" "eventbridge_step_functions" {
  name = "${var.utility_name}-eventbridge-sf-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "events.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "eventbridge_step_functions" {
  name = "${var.utility_name}-eventbridge-sf-policy"
  role = aws_iam_role.eventbridge_step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["states:StartExecution"], Resource = [aws_sfn_state_machine.grid_response.arn] }]
  })
}

resource "aws_iam_role" "bedrock" {
  name = "${var.utility_name}-bedrock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "bedrock.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "bedrock" {
  name = "${var.utility_name}-bedrock-policy"
  role = aws_iam_role.bedrock.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"], Resource = ["arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-3-5-sonnet-*"] },
      { Effect = "Allow", Action = ["bedrock:Retrieve"], Resource = ["arn:aws:bedrock:${var.region}:*:knowledge-base/${var.utility_name}-*"] }
    ]
  })
}

resource "aws_iam_role" "sagemaker" {
  name = "${var.utility_name}-sagemaker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "sagemaker.amazonaws.com" } }]
  })
}

# Data source
data "aws_caller_identity" "current" {}

# ============================================================
# Locals
# ============================================================

locals {
  common_tags = {
    Project     = "GridForge"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Utility     = var.utility_name
  }
}
