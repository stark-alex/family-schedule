terraform {
  backend "s3" {
    bucket = "stark-tf-state"
    key    = "family-schedule/shared.tfstate"
    region = "us-east-1"
  }
}
