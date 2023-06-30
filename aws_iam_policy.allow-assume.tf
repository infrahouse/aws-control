data "aws_iam_policy_document" "allow-assume" {
  provider = aws.aws-990466748045-uw1
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "allow-assume" {
  provider    = aws.aws-990466748045-uw1
  name        = "allow-assume"
  description = "Policy that allows Assume TF admin roles"
  policy      = data.aws_iam_policy_document.allow-assume.json
}
