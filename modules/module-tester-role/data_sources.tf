locals {
  gha_hostname = "token.actions.githubusercontent.com"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.gha_hostname}"
}
data "aws_iam_policy_document" "pytest-permissions" {
  statement {
    actions = [
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource",
      "ec2:DescribeRegions",
      "iam:TagPolicy",
      "iam:TagRole",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging"
    ]
    resources = ["*"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "role-trust" {
  dynamic "statement" {
    for_each = merge(
      var.trusted_iam_user_arn,
    )
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
    }
  }
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      variable = "aws:PrincipalArn"
      test     = "ArnEquals"
      values = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_name}"
      ]
    }

  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.gha_hostname}:aud"
      values = [
        "sts.amazonaws.com"
      ]
    }
    condition {
      test     = "StringLike"
      variable = "${local.gha_hostname}:sub"
      values = [
        "repo:${var.gh_org_name}/${var.repo_name}:*"
      ]
    }
  }
}

data "aws_iam_policy_document" "role-permissions" {
  statement {
    actions   = length(var.role_permissions) > 0 ? var.role_permissions : ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

data "aws_iam_policy" "administrator-access" {
  name = "AdministratorAccess"
}
