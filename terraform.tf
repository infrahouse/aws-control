terraform {
  backend "s3" {
    bucket  = "infrahouse8-aws-control"
    key     = "terraform.tfstate"
    region  = "us-west-1"
    profile = "infrahouse8"

    dynamodb_table = "infrahouse-aws-control-locks"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.56"
    }
  }
}
