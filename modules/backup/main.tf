module "dst" {
  source  = "registry.infrahouse.com/infrahouse/s3-bucket/aws"
  version = "0.3.1"

  bucket_prefix     = "twindb"
  enable_versioning = true
}

resource "aws_iam_user" "backuper" {
  name = module.dst.bucket_name
}

data "aws_iam_policy_document" "backuper-permissions" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      module.dst.bucket_arn
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${module.dst.bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "backuper" {
  policy = data.aws_iam_policy_document.backuper-permissions.json
}

resource "aws_iam_user_policy_attachment" "backuper" {
  policy_arn = aws_iam_policy.backuper.arn
  user       = aws_iam_user.backuper.name
}
