module "mediapc" {
  source = "./modules/backup"
  providers = {
    aws = aws.aws-990466748045-uw1
  }

}

output "mediapc-bucket" {
  value = module.mediapc.bucket
}

output "mediapc-access-key" {
  value     = module.mediapc.access_key
  sensitive = true
}

output "mediapc-secret-key" {
  value     = module.mediapc.secret_key
  sensitive = true
}

output "mediapc-region" {
  value = module.mediapc.aws_region
}
