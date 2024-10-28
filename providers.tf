provider "aws" {
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/aws-control-990466748045" # GitHub repository that created a resource
    }
  }
}

provider "aws" {
  alias  = "aws-990466748045-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/aws-control-990466748045" # GitHub repository that created a resource
    }
  }
}

provider "aws" {
  alias  = "aws-990466748045-uw2"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/aws-control-990466748045" # GitHub repository that created a resource
    }
  }
}

provider "aws" {
  alias  = "aws-990466748045-ue1"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/aws-control-990466748045" # GitHub repository that created a resource
    }
  }
}
