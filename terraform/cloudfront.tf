locals {
  s3_origin_id = "s3-${var.project_name}"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "schedule.html"
  price_class         = "PriceClass_100" # US, Canada, Europe — cheapest

  aliases = ["${var.schedule_subdomain}.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    # Forward cookies so the Lambda@Edge can read them
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    # Short TTL — Lambda@Edge handles auth on every viewer-request anyway
    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 300

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.auth.qualified_arn
      include_body = false
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
