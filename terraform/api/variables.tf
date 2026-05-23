variable "env_name" {
  description = "Environment name: prod | pr-123"
  type        = string
}

variable "authorization_type" {
  description = "Lambda Function URL auth: AWS_IAM for prod, NONE for preview"
  type        = string
  default     = "AWS_IAM"
}

variable "s3_bucket" {
  description = "Name of the shared content S3 bucket"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the shared content S3 bucket"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution — empty string for preview envs"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Prefix for AWS resource names"
  type        = string
  default     = "family-schedule"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
