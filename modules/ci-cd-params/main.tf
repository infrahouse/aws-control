resource "aws_ssm_parameter" "state_bucket" {
  name  = "/terraform/${var.repo_name}/backend/state_bucket"
  type  = "String"
  value = var.state_bucket
}

resource "aws_ssm_parameter" "lock_table" {
  name  = "/terraform/${var.repo_name}/backend/lock_table"
  type  = "String"
  value = var.lock_table
}

resource "aws_ssm_parameter" "state_manager_role_arn" {
  name  = "/terraform/${var.repo_name}/backend/state_manager_role_arn"
  type  = "String"
  value = var.state_manager_role_arn
}

resource "aws_ssm_parameter" "github_role_arn" {
  name  = "/terraform/${var.repo_name}/ci-cd/github_role_arn"
  type  = "String"
  value = var.github_role_arn
}

resource "aws_ssm_parameter" "admin_role_arn" {
  name  = "/terraform/${var.repo_name}/ci-cd/admin_role_arn"
  type  = "String"
  value = var.admin_role_arn
}