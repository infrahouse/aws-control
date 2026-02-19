terraform {
  backend "s3" {
    bucket = "infrahouse-aws-control-990466748045"
    key    = "terraform.tfstate"
    region = "us-west-1"
    assume_role = {
      role_arn = "arn:aws:iam::289256138624:role/ih-tf-aws-control-state-manager"
    }
    dynamodb_table = "infrahouse-aws-control-990466748045-active-polecat"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
}
