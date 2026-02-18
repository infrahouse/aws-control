# User
resource "aws_iam_user" "synology" {
  name = "synology"
}

data "aws_iam_policy_document" "synology-permissions" {
  statement {
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "glacier:AbortMultipartUpload",
      "glacier:CompleteMultipartUpload",
      "glacier:CreateVault",
      "glacier:DeleteArchive",
      "glacier:DescribeJob",
      "glacier:DescribeVault",
      "glacier:GetJobOutput",
      "glacier:InitiateJob",
      "glacier:InitiateMultipartUpload",
      "glacier:ListJobs",
      "glacier:ListMultipartUploads",
      "glacier:ListParts",
      "glacier:UploadArchive",
      "glacier:UploadMultipartPart",
    ]
    resources = [
      "arn:aws:glacier:us-west-1:990466748045:vaults/SynologyNAS*"
    ]
  }
  statement {
    actions = [
      "glacier:ListVaults"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "synology" {
  policy = data.aws_iam_policy_document.synology-permissions.json
}

resource "aws_iam_user_policy_attachment" "synology" {
  policy_arn = aws_iam_policy.synology.arn
  user       = aws_iam_user.synology.name
}

# Glacier
resource "aws_glacier_vault" "synology" {
  name = "synology"
}
