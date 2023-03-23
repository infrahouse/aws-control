resource "aws_iam_policy" "TFAWSAdmin" {
  name        = "TFAWSAdmin"
  description = "Policy that allows Assume TF admin roles"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : [
            aws_iam_role.github-admin.arn,
            aws_iam_role.s3-admin.arn
          ]
        },
      ]
    }
  )
  tags = merge(local.common_tags)
}

resource "aws_iam_policy" "dynamodb-lock" {
  name = "TFStateLocks"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem"
          ],
          "Resource" : aws_dynamodb_table.terraform_locks.arn
        }
      ]
  })
  tags = merge(local.common_tags)
}

resource "aws_iam_policy" "TFAdminForGitHub" {
  name        = "TFAdminForGitHub"
  description = "Policy that allows read-write access to the GitHub Terraform state bucket"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
          ],
          "Resource" : [
            "arn:aws:s3:::infrahouse-github-state/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "s3:ListBucket",
          "Resource" : "arn:aws:s3:::infrahouse-github-state"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "secretsmanager:CreateSecret",
            "secretsmanager:DeleteSecret",
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue"
          ],
          "Resource" : [
            "arn:aws:secretsmanager:*:${local.aws_account_id}:secret:${aws_ssm_parameter.gh_secrets_namespace.insecure_value}*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "secretsmanager:ListSecrets"
          ],
          "Resource" : ["*"]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ssm:GetParameter",
          ],
          "Resource" : [
            "arn:aws:ssm:${local.aws_default_region}:${local.aws_account_id}:parameter/gh_secrets_namespace"
          ]

        }
      ]
    }
  )
  tags = merge(local.common_tags)
}


resource "aws_iam_policy" "TFAdminForS3" {
  name        = "TFAdminForS3"
  description = "Policy that allows provisioning of S3 buckets"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
          ],
          "Resource" : [
            "arn:aws:s3:::infrahouse-aws-s3-control/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : "s3:ListBucket",
          "Resource" : "arn:aws:s3:::infrahouse-aws-s3-control"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:CreateBucket",
            "s3:GetAccelerateConfiguration",
            "s3:GetBucketAcl",
            "s3:GetBucketCors",
            "s3:GetBucketLogging",
            "s3:GetBucketObjectLockConfiguration",
            "s3:GetBucketPolicy",
            "s3:GetBucketPublicAccessBlock",
            "s3:GetBucketRequestPayment",
            "s3:GetBucketTagging",
            "s3:GetBucketVersioning",
            "s3:GetBucketWebsite",
            "s3:GetEncryptionConfiguration",
            "s3:GetLifecycleConfiguration",
            "s3:GetReplicationConfiguration",
            "s3:ListBucket",
            "s3:PutBucketPublicAccessBlock",
            "s3:PutBucketTagging",
            "s3:PutBucketVersioning",
            "s3:PutEncryptionConfiguration",
          ],
          "Resource" : [
            "*"
          ]
        }
      ]
    }
  )
  tags = merge(local.common_tags)
}
