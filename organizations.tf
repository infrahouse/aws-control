import {
  to = aws_organizations_organization.infrahouse
  id = "o-85w62lgze7"
}

resource "aws_organizations_organization" "infrahouse" {
  aws_service_access_principals = [
    "account.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "controltower.amazonaws.com",
    "iam.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
    "sso.amazonaws.com",
  ]
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  feature_set          = "ALL"
}

import {
  to = aws_organizations_organizational_unit.infrastructure
  id = "ou-k4pv-0kpta53f"
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.production
  id = "ou-k4pv-zrkq0fya"
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.infrastructure.id
}

import {
  to = aws_organizations_organizational_unit.sandbox
  id = "ou-k4pv-3gyd2btz"
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.deployments
  id = "ou-k4pv-jvoszl0b"
}

resource "aws_organizations_organizational_unit" "deployments" {
  name      = "Deployments"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.suspended
  id = "ou-k4pv-m9l7qrwe"
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.security
  id = "ou-k4pv-n9tx2u2v"
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.policy_staging
  id = "ou-k4pv-ub39j8u5"
}

resource "aws_organizations_organizational_unit" "policy_staging" {
  name      = "Policy Staging"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_organizational_unit.workloads
  id = "ou-k4pv-xn24jiri"
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.infrahouse.roots[0].id
}

import {
  to = aws_organizations_account.cicd
  id = "303467602807"
}

resource "aws_organizations_account" "cicd" {
  name              = "CI-CD"
  email             = "billing+cicd@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.infrastructure.id
  close_on_deletion = false
  create_govcloud   = false
}

import {
  to = aws_organizations_account.log_archive
  id = "338531211565"
}

resource "aws_organizations_account" "log_archive" {
  name              = "Log Archive"
  email             = "billing+log-archive@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.security.id
  close_on_deletion = false
  create_govcloud   = false
}

import {
  to = aws_organizations_account.audit
  id = "076816212431"
}

resource "aws_organizations_account" "audit" {
  name              = "Audit"
  email             = "billing+audit@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.security.id
  close_on_deletion = false
  create_govcloud   = false
}

import {
  to = aws_organizations_account.management
  id = "493370826424"
}

resource "aws_organizations_account" "management" {
  name              = "InfraHouse Management"
  email             = "billing+management@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.production.id
  close_on_deletion = false
  create_govcloud   = false
}

import {
  to = aws_organizations_account.terraform_control
  id = "289256138624"
}

resource "aws_organizations_account" "terraform_control" {
  name              = "terraform-control"
  email             = "billing+terraform-control@infrahouse.com"
  parent_id         = aws_organizations_organizational_unit.production.id
  close_on_deletion = false
  create_govcloud   = false
}
