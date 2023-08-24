resource "aws_s3_bucket" "dst" {
  bucket_prefix = "twindb"
}

resource "aws_iam_user" "backuper" {
  name = aws_s3_bucket.dst.bucket
}

resource "aws_iam_access_key" "backuper" {
  user = aws_iam_user.backuper.name
}

data "aws_iam_policy_document" "backuper-permissions" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.dst.arn
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.dst.arn}/*"
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
