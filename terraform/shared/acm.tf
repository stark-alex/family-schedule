# Wildcard cert for *.yourdomain.com — must be in us-east-1 for CloudFront
resource "aws_acm_certificate" "main" {
  provider    = aws.us_east_1
  domain_name = "*.${var.domain_name}"
  # Also cover the apex in case you want it later
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "main" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
