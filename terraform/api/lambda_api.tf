locals {
  # Prod keeps the original name for state migration compatibility; PR envs get a suffix
  function_name = var.env_name == "prod" ? "${var.project_name}-api" : "${var.project_name}-api-${var.env_name}"
}

data "aws_ssm_parameter" "origin_verify_secret" {
  name            = "/family-schedule/origin-verify-secret"
  with_decryption = true
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
  source_code_hash = fileexists("${path.module}/../../terraform/lambda/api.zip") ? filebase64sha256("${path.module}/../../terraform/lambda/api.zip") : null
  function_name    = local.function_name
  role             = aws_iam_role.api_lambda.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["arm64"]

  environment {
    variables = {
      S3_BUCKET            = var.s3_bucket
      ORIGIN_VERIFY_SECRET = data.aws_ssm_parameter.origin_verify_secret.value
      S3_KEY               = var.s3_key
    }
  }
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "PUT"]
    allow_headers = ["content-type", "x-origin-verify"]
  }
}
