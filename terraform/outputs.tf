output "schedule_url" {
  value = "https://${var.schedule_subdomain}.${var.domain_name}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.content.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.main.id
}
