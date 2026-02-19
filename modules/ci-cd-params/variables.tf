variable "repo_name" {
  description = "Repository name (e.g. aws-control-338531211565). Used as SSM parameter namespace."
  type        = string
}

variable "state_bucket" {
  description = "S3 state bucket name."
  type        = string
}

variable "lock_table" {
  description = "DynamoDB lock table name."
  type        = string
}

variable "state_manager_role_arn" {
  description = "State manager role ARN."
  type        = string
}

variable "github_role_arn" {
  description = "GitHub Actions role ARN."
  type        = string
}

variable "admin_role_arn" {
  description = "Admin role ARN."
  type        = string
}