output "role_arn" {
  description = "Role ARN."
  value       = aws_iam_role.role-tester.arn
}

output "role_name" {
  description = "Role name."
  value       = aws_iam_role.role-tester.name
}

output "permissions_policy_arn" {
  description = "ARN of the policy with the role permissions."
  value       = aws_iam_policy.role-permissions.arn
}
