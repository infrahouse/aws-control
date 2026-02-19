provider "aws" {
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-990466748045-uw2"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-990466748045-ue1"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::990466748045:role/ih-tf-aws-control-admin"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-338531211565-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::338531211565:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-289256138624-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::289256138624:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-303467602807-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::303467602807:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-493370826424-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::493370826424:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}
