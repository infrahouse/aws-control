resource "aws_identitystore_user" "aleks" {
  provider          = aws.aws-990466748045-uw1
  identity_store_id = local.instance_arn

  display_name = "Oleksandr Kuzminskyi"
  user_name    = "aleks"

  name {
    given_name  = "Oleksandr"
    family_name = "Kuzminskyi"
  }

  emails {
    value = "aleks@infrahouse.com"
  }
}