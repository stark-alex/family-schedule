variable "env_name" {
  description = "Environment name: prod | pr-123"
  type        = string
}

variable "s3_bucket" {
  description = "Name of the shared content S3 bucket"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the shared content S3 bucket"
  type        = string
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
