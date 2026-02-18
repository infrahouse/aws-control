module "mediapc" {
  source = "./modules/backup"
  providers = {
    aws = aws.aws-990466748045-uw1
  }

}
