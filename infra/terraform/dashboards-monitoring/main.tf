# GridForge — Dashboards & Monitoring Module
# QuickSight, CloudWatch Dashboards, CloudWatch Alarms, SNS Topics, SES

# ============================================================
# SNS Topics — Notification routing for grid events
# ============================================================

resource "aws_sns_topic" "critical_grid" {
  name = "${var.utility_name}-critical-grid-events"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-critical-grid-events"
    Severity = "CRITICAL"
  })
}

resource "aws_sns_topic" "ops_alerts" {
  name = "${var.utility_name}-operational-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-operational-alerts"
    Severity = "MEDIUM-HIGH"
  })
}

resource "aws_sns_topic" "cost_alerts" {
  name = "${var.utility_name}-cost-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.utility_name}-cost-alerts"
    Severity = "INFO"
  })
}

# SNS email subscription (if alert email provided)
resource "aws_sns_topic_subscription" "critical_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_grid.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "ops_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "cost_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# CloudWatch Alarms — Critical infrastructure monitoring
# ============================================================

# Alarm 1: IoT message rate drop — indicates meter connectivity issues
resource "aws_cloudwatch_metric_alarm" "iot_message_rate_drop" {
  alarm_name          = "${var.utility_name}-iot-message-rate-drop"
  alarm_description   = "IoT message rate dropped below ${var.iot_message_rate_threshold}/min — possible meter connectivity issue"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Success"
  namespace           = "AWS/IoT"
  period              = 60
  statistic           = "Sum"
  threshold           = var.iot_message_rate_threshold
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.critical_grid.arn]
  ok_actions    = [aws_sns_topic.ops_alerts.arn]

  tags = local.common_tags
}

# Alarm 2: Lambda error rate — anomaly detector malfunction
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.utility_name}-lambda-error-rate"
  alarm_description   = "Lambda anomaly detector error rate exceeds ${var.lambda_error_rate_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_error_rate_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${var.utility_name}-anomaly-detector"
  }

  alarm_actions = [aws_sns_topic.ops_alerts.arn]

  tags = local.common_tags
}

# Alarm 3: Kinesis iterator age — processing lag
resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${var.utility_name}-kinesis-iterator-age"
  alarm_description   = "Kinesis iterator age exceeds ${var.kinesis_iterator_age_threshold}ms — processing is lagging"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.kinesis_iterator_age_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    StreamName = "${var.utility_name}-telemetry"
  }

  alarm_actions = [aws_sns_topic.ops_alerts.arn]

  tags = local.common_tags
}

# Alarm 4: Estimated charges — cost monitoring
resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  alarm_name          = "${var.utility_name}-estimated-charges"
  alarm_description   = "AWS estimated charges exceed ${var.monthly_cost_threshold} USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600  # 6 hours
  statistic           = "Maximum"
  threshold           = var.monthly_cost_threshold

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.cost_alerts.arn]

  tags = local.common_tags
}

# ============================================================
# CloudWatch Dashboard — Infrastructure metrics
# ============================================================

resource "aws_cloudwatch_dashboard" "gridforge_infra" {
  dashboard_name = "${var.utility_name}-GridForge-Infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "IoT Core — Message Rate"
          region  = var.region
          metrics = [
            ["AWS/IoT", "Success", { stat = "Sum", period = 60 }],
            ["AWS/IoT", "Failure", { stat = "Sum", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Kinesis — Iterator Age (ms)"
          region  = var.region
          metrics = [
            ["AWS/Kinesis", "GetRecords.IteratorAgeMilliseconds", { stat = "Maximum", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Anomaly Detector"
          region  = var.region
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", period = 60 }],
            ["AWS/Lambda", "Errors", { stat = "Sum", period = 60 }],
            ["AWS/Lambda", "Duration", { stat = "Average", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Timestream — Query Latency"
          region  = var.region
          metrics = [
            ["AWS/Timestream", "QueryLatency", { stat = "Average", period = 300 }]
          ]
        }
      }
    ]
  })
}

# ============================================================
# QuickSight — Grid Operations Center Dashboard
# ============================================================

# Note: QuickSight requires manual user setup via AWS Console
# This creates the data source and dataset configuration

resource "aws_quicksight_data_source" "timestream" {
  count = var.enable_quicksight ? 1 : 0

  data_source_id = "${replace(var.utility_name, "-", "")}-timestream-source"
  name           = "${var.utility_name} Timestream Source"

  parameters {
    timestream {
      cluster = "arn:aws:timestream:${var.region}:*:database/${var.timestream_database_name}"
    }
  }

  tags = local.common_tags
}

# ============================================================
# SES — Email alert sender
# ============================================================

resource "aws_ses_email_identity" "alert_sender" {
  count = var.alert_email != "" ? 1 : 0
  email = var.alert_email
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
