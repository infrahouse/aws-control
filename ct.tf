import {
  to = awscc_controltower_landing_zone.root
  id = "253SSA9Y0WZPC0ZN"
}

resource "awscc_controltower_landing_zone" "root" {
  manifest = jsonencode({
    accessManagement = {
      enabled = true
    }
    securityRoles = {
      accountId = "076816212431"
    }
    backup = {
      enabled = false
    }
    governedRegions = [
      "us-east-2",
      "us-west-1",
      "us-east-1",
      "us-west-2",
    ]
    organizationStructure = {
      security = {
        name = "Security"
      }
    }
    centralizedLogging = {
      accountId = "338531211565"
      configurations = {
        loggingBucket = {
          retentionDays = 365
        }
        accessLoggingBucket = {
          retentionDays = 3650
        }
      }
      enabled = true
    }
  })
  version           = "3.3"
  remediation_types = ["INHERITANCE_DRIFT"]
}

locals {
  # Parse region from the landing zone ARN: arn:aws:controltower:<region>:...
  ct_home_region             = element(split(":", awscc_controltower_landing_zone.root.arn), 3)
  baseline_identity_center   = "arn:aws:controltower:${local.ct_home_region}::baseline/LN25R72TTG6IGPTQ"
  baseline_audit             = "arn:aws:controltower:${local.ct_home_region}::baseline/4T4HA1KMO10S6311"
  baseline_log_archive       = "arn:aws:controltower:${local.ct_home_region}::baseline/J8HX46AHS5MIKQPD"
  baseline_aws_control_tower = "arn:aws:controltower:${local.ct_home_region}::baseline/17BSJV3IGJ2QSGA2"
  # Enabled baseline ARN for IdentityCenter — hardcoded until account-level baselines can be imported
  identity_center_enabled_baseline_arn = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XAP0DVO6CUI4940JO"
}

# Account-level baselines are commented out due to a provider bug:
# hashicorp/terraform-provider-aws#45871
# The provider doesn't read baseline_version during import for account-targeted
# baselines, causing forced replacement. Uncomment when the bug is fixed.
#
# import {
#   to = aws_controltower_baseline.identity_center
#   id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XAP0DVO6CUI4940JO"
# }
#
# resource "aws_controltower_baseline" "identity_center" {
#   baseline_identifier = local.baseline_identity_center
#   baseline_version    = "4.0"
#   target_identifier   = aws_organizations_organization.infrahouse.master_account_arn
# }
#
# import {
#   to = aws_controltower_baseline.audit
#   id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XADCNRRD70A4940MG"
# }
#
# resource "aws_controltower_baseline" "audit" {
#   baseline_identifier = local.baseline_audit
#   baseline_version    = "4.0"
#   target_identifier   = aws_organizations_account.audit.arn
# }
#
# import {
#   to = aws_controltower_baseline.log_archive
#   id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XAHOV133Y2L4940L0"
# }
#
# resource "aws_controltower_baseline" "log_archive" {
#   baseline_identifier = local.baseline_log_archive
#   baseline_version    = "4.0"
#   target_identifier   = aws_organizations_account.log_archive.arn
# }

# AWSControlTowerBaseline (on OUs)

import {
  to = aws_controltower_baseline.infrastructure
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XOH16ARMKWD4942WE"
}

resource "aws_controltower_baseline" "infrastructure" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.infrastructure.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.sandbox
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XOKXFUJSAGD4942SG"
}

resource "aws_controltower_baseline" "sandbox" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.sandbox.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.deployments
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XO0C59G2HSD4944GA"
}

resource "aws_controltower_baseline" "deployments" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.deployments.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.suspended
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XO3Q2O78DVD49420V"
}

resource "aws_controltower_baseline" "suspended" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.suspended.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.policy_staging
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XOBSKQ0PBMD4944UY"
}

resource "aws_controltower_baseline" "policy_staging" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.policy_staging.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.workloads
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XOE4JL0Z8ZD4944QM"
}

resource "aws_controltower_baseline" "workloads" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.workloads.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}

import {
  to = aws_controltower_baseline.production
  id = "arn:aws:controltower:us-west-1:990466748045:enabledbaseline/XOG817HWFRD4944DK"
}

resource "aws_controltower_baseline" "production" {
  baseline_identifier = local.baseline_aws_control_tower
  baseline_version    = "4.0"
  target_identifier   = aws_organizations_organizational_unit.production.arn

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = local.identity_center_enabled_baseline_arn
  }
}
