terraform {
  backend "s3" {
    bucket = "stark-tf-state"
    region = "us-east-1"
    # key is intentionally omitted — always pass -backend-config="key=..." at init time
  }
}
