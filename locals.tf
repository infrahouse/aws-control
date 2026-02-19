locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.sso.identity_store_ids)[0]
  default_tags = {
    "created_by"  = "infrahouse/aws-control"
    "environment" = "production"
  }
}
