provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-eu-central-1"
    key    = "aws/k8s-module-test/opsbridge-cluster/terraform.tfstate"
    region = "eu-central-1"

  }
}