# Copy this to terraform.tfvars and fill in your values.
# terraform.tfvars is gitignored if it contains secrets — this example file is safe to commit.

aws_region     = "us-east-1"
domain_name    = "atmj-stark.com"         # your registered domain
hosted_zone_id = "Z080516033FJW6UYROIRY"  # Route 53 hosted zone ID (from console after registering)

# Subdomains — defaults are fine, change only if you want something different
schedule_subdomain = "schedule"           # → schedule.atmj-stark.com
auth_subdomain     = "auth"               # → auth.atmj-stark.com (Cognito hosted UI)

project_name = "family-schedule"
