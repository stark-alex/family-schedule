locals {
  auth_lambda_config = {
    user_pool_id     = aws_cognito_user_pool.main.id
    user_pool_region = var.aws_region
    client_id        = aws_cognito_user_pool_client.main.id
    cognito_domain   = "https://${var.auth_subdomain}.${var.domain_name}"
    callback_url     = "https://${var.schedule_subdomain}.${var.domain_name}/callback"
    schedule_url     = "https://${var.schedule_subdomain}.${var.domain_name}"
  }
}

# Render the template with Cognito values baked in (Lambda@Edge has no env vars)
data "archive_file" "auth_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda/auth.zip"

  source {
    content  = templatefile("${path.module}/lambda/auth.js.tpl", local.auth_lambda_config)
    filename = "auth.js"
  }
}

resource "aws_iam_role" "lambda_edge" {
  provider = aws.us_east_1
  name     = "${var.project_name}-lambda-edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_logs" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "auth" {
  provider = aws.us_east_1

  filename         = data.archive_file.auth_lambda.output_path
  source_code_hash = data.archive_file.auth_lambda.output_base64sha256
  function_name    = "${var.project_name}-auth"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "auth.handler"
  runtime          = "nodejs20.x"
  publish          = true # Lambda@Edge requires a published version (not $LATEST)

  # Lambda@Edge does not support environment variables —
  # config is baked into the source via templatefile above.
}
