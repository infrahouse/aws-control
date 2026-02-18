module "mediapc" {
  source = "./modules/backup"
  providers = {
    aws = aws.aws-990466748045-uw1
  }

}

output "mediapc-bucket" {
  value = module.mediapc.bucket
}

output "mediapc-region" {
  value = module.mediapc.aws_region
}
