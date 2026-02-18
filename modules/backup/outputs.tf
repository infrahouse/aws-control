output "bucket" {
  description = "S3 bucket for a backup destination."
  value       = module.dst.bucket_name
}

output "aws_region" {
  description = "AWS region where the bucket is created"
  value       = data.aws_region.current.name
}
