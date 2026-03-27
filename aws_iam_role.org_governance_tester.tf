module "org_governance_tester" {
  source = "./modules/module-tester-role"

  gh_org_name             = "infrahouse"
  repo_name               = "terraform-aws-org-governance"
  role_name               = "org-governance-tester"
  max_session_duration    = 43200
  grant_admin_permissions = true
  trusted_iam_user_arn    = { sso-admin : tolist(data.aws_iam_roles.sso_admin.arns)[0] }

  depends_on = [module.github_connector]
}
