# Store these before running terraform apply:
#   aws ssm put-parameter --name "/family-schedule/google_client_id" --value "..." --type SecureString
#   aws ssm put-parameter --name "/family-schedule/google_client_secret" --value "..." --type SecureString

data "aws_ssm_parameter" "google_client_id" {
  name            = "/family-schedule/google_client_id"
  with_decryption = true
}

data "aws_ssm_parameter" "google_client_secret" {
  name            = "/family-schedule/google_client_secret"
  with_decryption = true
}

resource "aws_cognito_user_pool" "main" {
  name                     = var.project_name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = data.aws_ssm_parameter.google_client_id.value
    client_secret    = data.aws_ssm_parameter.google_client_secret.value
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Public client — uses PKCE instead of a client secret
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO", "Google"]

  callback_urls = ["https://${var.schedule_subdomain}.${var.domain_name}/callback"]
  logout_urls   = ["https://${var.schedule_subdomain}.${var.domain_name}"]

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  depends_on = [aws_cognito_identity_provider.google]
}

# Custom domain for the hosted UI — requires the wildcard cert
resource "aws_cognito_user_pool_domain" "main" {
  domain          = "${var.auth_subdomain}.${var.domain_name}"
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn
  user_pool_id    = aws_cognito_user_pool.main.id
}
