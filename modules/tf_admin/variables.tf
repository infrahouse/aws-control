variable "username" {
  description = "Username of a Terraform admin account"
  type        = string
}

variable "tags" {
  description = "Tags to apply on created resources"
  type        = map(string)
  default     = {}
}
