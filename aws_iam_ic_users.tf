resource "aws_identitystore_user" "aleks" {
  provider          = aws.aws-990466748045-uw1
  identity_store_id = local.identity_store_id

  display_name = "Oleksandr Kuzminskyi"
  user_name    = "aleks"

  name {
    given_name  = "Oleksandr"
    family_name = "Kuzminskyi"
  }

  emails {
    primary = true
    type    = "work"
    value   = "aleks@infrahouse.com"
  }
}