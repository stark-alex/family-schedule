output "api_function_url" {
  value       = aws_lambda_function_url.api.function_url
  description = "Lambda Function URL for the API"
}

output "api_function_name" {
  value = aws_lambda_function.api.function_name
}
