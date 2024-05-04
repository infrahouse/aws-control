# User
resource "aws_iam_user" "synology" {
  name = "synology"
}

resource "aws_iam_access_key" "synology" {
  user = aws_iam_user.synology.name
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
      "glacier:*"
    ]
    resources = [
      "arn:aws:glacier:us-west-1:990466748045:vaults/SynologyNAS*"
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

output "synology-access-key" {
  value     = aws_iam_access_key.synology.id
  sensitive = true
}

output "synology-secret-key" {
  value     = aws_iam_access_key.synology.secret
  sensitive = true
}

# Glacier
resource "aws_glacier_vault" "synology" {
  name = "synology"
}
