# GridForge — Cost Optimization Module
# AWS Budgets, Spot recommendations, Reserved capacity analysis

# ============================================================
# AWS Budgets — Monthly cost monitoring and alerts
# ============================================================

resource "aws_budgets_budget" "monthly" {
  name         = "${var.utility_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alert at 80% of budget
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Alert at 100% of budget
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Forecasted alert at 100% (early warning)
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  cost_filters = {
    TagKeyValue = "user:Project$GridForge"
  }

  tags = local.common_tags
}

# ============================================================
# Lambda: Cost Monitor — Daily cost tracking and optimization
# ============================================================

data "archive_file" "cost_monitor" {
  type        = "zip"
  source_dir  = var.cost_monitor_source_dir
  output_path = "${path.module}/../lambda-packages/cost-monitor.zip"
}

resource "aws_lambda_function" "cost_monitor" {
  function_name = "${var.utility_name}-cost-monitor"
  description   = "Monitors AWS spending, generates alerts, and recommends cost optimizations"
  role          = aws_iam_role.cost_monitor.arn
  handler       = "index.lambda_handler"

  filename         = data.archive_file.cost_monitor.output_path
  source_code_hash = data.archive_file.cost_monitor.output_base64sha256

  runtime       = "python3.11"
  architectures = [var.lambda_architecture]
  memory_size   = 128
  timeout       = 60

  environment {
    variables = {
      BUDGET_LIMIT      = tostring(var.budget_limit)
      SNS_TOPIC_ARN     = var.sns_topic_arns["cost-alerts"]
      UTILITY_NAME      = var.utility_name
      REGION            = var.region
      LOG_LEVEL         = "INFO"
    }
  }

  kms_key_arn = var.lambda_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-cost-monitor"
  })
}

# Schedule: Run daily at 8 AM UTC
resource "aws_cloudwatch_event_rule" "cost_monitor_schedule" {
  name                = "${var.utility_name}-cost-monitor-schedule"
  description         = "Run cost monitor daily at 8 AM UTC"
  schedule_expression = "cron(0 8 * * ? *)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "cost_monitor" {
  rule      = aws_cloudwatch_event_rule.cost_monitor_schedule.name
  target_id = "CostMonitorLambda"
  arn       = aws_lambda_function.cost_monitor.arn
}

resource "aws_lambda_permission" "cost_monitor_schedule" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_monitor_schedule.arn
}

# ============================================================
# IAM Role for Cost Monitor Lambda
# ============================================================

resource "aws_iam_role" "cost_monitor" {
  name = "${var.utility_name}-cost-monitor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cost_monitor" {
  name = "${var.utility_name}-cost-monitor-policy"
  role = aws_iam_role.cost_monitor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "budgets:DescribeBudgets",
          "budgets:ViewBudget",
          "ce:GetCostAndUsage",
          "ce:GetReservationCoverage",
          "ce:GetRightsizingRecommendation",
          "ce:GetSavingsPlansPurchaseRecommendation"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = [var.sns_topic_arns["cost-alerts"]]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:${var.region}:*:*"]
      }
    ]
  })
}

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
