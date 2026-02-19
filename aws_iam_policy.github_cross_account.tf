# Allow the github role to assume AWSControlTowerExecution in managed accounts.
# This is a temporary bridge until we upgrade this repo's own gha-admin to v3.6.1,
# which supports the allowed_arns variable natively.

resource "aws_iam_policy" "github_cross_account" {
  name        = "ih-tf-aws-control-github-cross-account"
  description = "Allow ih-tf-aws-control-github to assume roles in managed accounts"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeControlTowerExecution"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
          "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_cross_account" {
  role       = "ih-tf-aws-control-github"
  policy_arn = aws_iam_policy.github_cross_account.arn
}