resource "aws_organizations_account" "cicd" {
  name              = "CI-CD"
  email             = "billing+cicd@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.infrastructure.id
  close_on_deletion = false
  create_govcloud   = false
}

resource "aws_organizations_account" "log_archive" {
  name              = "Log Archive"
  email             = "billing+log-archive@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.security.id
  close_on_deletion = false
  create_govcloud   = false
}

resource "aws_organizations_account" "audit" {
  name              = "Audit"
  email             = "billing+audit@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.security.id
  close_on_deletion = false
  create_govcloud   = false
}

resource "aws_organizations_account" "management" {
  name              = "InfraHouse Management"
  email             = "billing+management@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.production.id
  close_on_deletion = false
  create_govcloud   = false
}

resource "aws_organizations_account" "terraform_control" {
  name              = "terraform-control"
  email             = "billing+terraform-control@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.production.id
  close_on_deletion = false
  create_govcloud   = false
}
