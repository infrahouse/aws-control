resource "aws_iam_policy" "pytest-permissions" {
  name_prefix = "pytest-permissions"
  policy      = data.aws_iam_policy_document.pytest-permissions.json
}

resource "aws_iam_policy" "role-permissions" {
  name_prefix = "${var.role_name}-permissions"
  policy      = data.aws_iam_policy_document.role-permissions.json
}

resource "aws_iam_role" "role-tester" {
  name                 = var.role_name
  description          = "Role to test module ${var.gh_org_name}/${var.repo_name}"
  assume_role_policy   = data.aws_iam_policy_document.role-trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "role-pytest-permissions" {
  policy_arn = aws_iam_policy.pytest-permissions.arn
  role       = aws_iam_role.role-tester.name
}

resource "aws_iam_role_policy_attachment" "role-permissions" {
  policy_arn = aws_iam_policy.role-permissions.arn
  role       = aws_iam_role.role-tester.name
}

resource "aws_iam_role_policy_attachment" "role-admin-permissions" {
  count      = var.grant_admin_permissions ? 1 : 0
  policy_arn = data.aws_iam_policy.administrator-access.arn
  role       = aws_iam_role.role-tester.name
}
