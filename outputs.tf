output "mediapc_bucket" {
  description = "S3 bucket name for mediapc backups."
  value       = module.mediapc.bucket
}

output "mediapc_region" {
  description = "AWS region of the mediapc backup bucket."
  value       = module.mediapc.aws_region
}
