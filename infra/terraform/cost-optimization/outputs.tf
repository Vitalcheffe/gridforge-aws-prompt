# GridForge — Cost Optimization Module Outputs

output "budget_name" {
  description = "AWS Budget name"
  value       = aws_budgets_budget.monthly.name
}

output "cost_monitor_lambda_arn" {
  description = "Cost monitor Lambda ARN"
  value       = aws_lambda_function.cost_monitor.arn
}

output "cost_monitor_lambda_name" {
  description = "Cost monitor Lambda function name"
  value       = aws_lambda_function.cost_monitor.function_name
}
