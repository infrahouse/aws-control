output "bucket" {
  description = "S3 bucket for a backup destination."
  value       = aws_s3_bucket.dst.bucket
}

output "aws_region" {
  description = "AWS region where the bucket is created"
  value       = aws_s3_bucket.dst.region
}
