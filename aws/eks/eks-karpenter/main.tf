provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-eu-central-1"
    key    = "aws/opsbridge-cluster/terraform.tfstate"
    region = "eu-central-1"
  }
}