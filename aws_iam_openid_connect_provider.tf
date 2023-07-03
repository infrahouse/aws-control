resource "aws_iam_openid_connect_provider" "github" {
  provider = aws.aws-990466748045-uw1
  url      = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = [
    # Generated with
    # https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}
