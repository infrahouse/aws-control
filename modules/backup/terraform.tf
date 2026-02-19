terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11, < 7.0"
    }
  }
}

data "aws_region" "current" {}
