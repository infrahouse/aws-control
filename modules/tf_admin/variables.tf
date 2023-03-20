variable "gh_secrets_namespace" {
  description = "Namespace prefix in the secrets manager where secrets accessible for GitHub are stored"
  type        = string
}
variable "username" {
  description = "Username of a Terraform admin account"
  type        = string
}

variable "tags" {
  description = "Tags to apply on created resources"
  type        = map(string)
  default     = {}
}
