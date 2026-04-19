# Bootstrap: create this bucket before running terraform init
# aws s3 mb s3://YOUR-STATE-BUCKET --region us-east-1
# aws s3api put-bucket-versioning --bucket YOUR-STATE-BUCKET --versioning-configuration Status=Enabled
# aws s3api put-public-access-block --bucket YOUR-STATE-BUCKET \
#   --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

terraform {
  backend "s3" {
    bucket = "stark-tf-state" # change to your bucket name
    key    = "family-schedule/terraform.tfstate"
    region = "us-east-1"
  }
}
