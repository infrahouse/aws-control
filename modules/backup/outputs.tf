output "bucket" {
  description = "S3 bucket for a backup destination."
  value       = aws_s3_bucket.dst.bucket
}

output "access_key" {
  description = "AWS_ACCESS_KEY_ID value."
  value       = aws_iam_access_key.backuper.id
  sensitive   = true
}

output "secret_key" {
  description = "AWS_SECRET_ACCESS_KEY value."
  value       = aws_iam_access_key.backuper.secret
  sensitive   = true
}

output "aws_region" {
  description = "AWS region where the bucket is created"
  value       = aws_s3_bucket.dst.region
}
