variable "aws_region" {
  description = "Primary AWS region for non-CloudFront resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain (e.g. starkfamily.com)"
  type        = string
}

variable "schedule_subdomain" {
  description = "Subdomain for the schedule app"
  type        = string
  default     = "schedule"
}

variable "auth_subdomain" {
  description = "Subdomain for Cognito hosted UI"
  type        = string
  default     = "auth"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID — get this from the console after registering the domain"
  type        = string
}

variable "project_name" {
  description = "Prefix for AWS resource names"
  type        = string
  default     = "family-schedule"
}
