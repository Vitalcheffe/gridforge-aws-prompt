# GridForge — Dashboards & Monitoring Module Outputs

output "sns_topic_arns" {
  description = "SNS topic ARNs (critical-grid, ops-alerts, cost-alerts)"
  value = {
    "critical-grid" = aws_sns_topic.critical_grid.arn
    "ops-alerts"    = aws_sns_topic.ops_alerts.arn
    "cost-alerts"   = aws_sns_topic.cost_alerts.arn
  }
}

output "quicksight_dashboard_url" {
  description = "QuickSight dashboard URL"
  value       = try("https://${var.region}.quicksight.aws.amazon.com/sn/dashboards/${aws_quicksight_data_source.timestream[0].data_source_id}", "")
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.gridforge_infra.dashboard_name}"
}
