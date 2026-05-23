locals {
  # Prod keeps the original name for state migration compatibility; PR envs get a suffix
  function_name = var.env_name == "prod" ? "${var.project_name}-api" : "${var.project_name}-api-${var.env_name}"
}

resource "aws_iam_role" "api_lambda" {
  name = local.function_name

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
      Resource = "${var.s3_bucket_arn}/schedule.yaml"
    }]
  })
}

resource "aws_lambda_function" "api" {
  filename         = "${path.module}/../../terraform/lambda/api.zip"
  source_code_hash = filebase64sha256("${path.module}/../../terraform/lambda/api.zip")
  function_name    = local.function_name
  role             = aws_iam_role.api_lambda.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["arm64"]

  environment {
    variables = {
      S3_BUCKET = var.s3_bucket
    }
  }
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = var.authorization_type

  dynamic "cors" {
    for_each = var.authorization_type == "NONE" ? [1] : []
    content {
      allow_origins = ["*"]
      allow_methods = ["GET", "PUT"]
      allow_headers = ["content-type"]
    }
  }
}

# Only grant CloudFront invoke permission for prod (AWS_IAM) deployments
resource "aws_lambda_permission" "api_from_cloudfront" {
  count = var.cloudfront_distribution_arn != "" ? 1 : 0

  statement_id           = "AllowCloudFrontInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = var.cloudfront_distribution_arn
  function_url_auth_type = "AWS_IAM"
}
