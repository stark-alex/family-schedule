output "api_function_url" {
  value       = aws_apigatewayv2_stage.api.invoke_url
  description = "API Gateway invoke URL"
}

output "api_function_name" {
  value = aws_lambda_function.api.function_name
}
