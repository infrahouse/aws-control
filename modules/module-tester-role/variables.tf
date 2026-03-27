variable "gh_org_name" {
  description = "GitHub organization name."
  type        = string
}

variable "grant_admin_permissions" {
  description = "Whether grant admin permissions to the role."
  type        = bool
  default     = false
}
variable "max_session_duration" {
  description = "Maximum session duration (in seconds) that you want to set for the specified role."
  default     = 3600
}

variable "repo_name" {
  description = "Repository name in GitHub. Without the organization part."
}

variable "role_name" {
  description = "Role name"
  type        = string
}
variable "role_permissions" {
  description = "List of actions the role can do. The action will be allowed on all resources i.e. `*`."
  default     = []
  type        = list(string)
}

variable "trusted_iam_user_arn" {
  description = "Map of ARN of a user or role that can assume the tester role. Useful for local testing."
  default     = {}
  type        = map(string)
}
