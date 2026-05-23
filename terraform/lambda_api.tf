resource "aws_iam_role" "api_lambda" {
  name = "${var.project_name}-api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_lambda_logs" {
  role       = aws_iam_role.api_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "api_lambda_s3" {
  name = "s3-schedule"
  role = aws_iam_role.api_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.content.arn}/schedule.yaml"
    }]
  })
}

resource "aws_lambda_function" "api" {
  filename         = "${path.module}/lambda/api.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/api.zip")
  function_name    = "${var.project_name}-api"
  role             = aws_iam_role.api_lambda.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["arm64"]

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.content.bucket
    }
  }
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}

# Allows CloudFront (and only this distribution) to invoke the Function URL via OAC signing.
# CloudFront wiring lives in cloudfront.tf — this permission is a prerequisite for PR 2.
resource "aws_lambda_permission" "api_from_cloudfront" {
  statement_id           = "AllowCloudFrontInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.main.arn
  function_url_auth_type = "AWS_IAM"
}

output "api_lambda_function_url" {
  value       = aws_lambda_function_url.api.function_url
  description = "Direct Lambda Function URL (IAM-signed only — not publicly accessible)"
}
