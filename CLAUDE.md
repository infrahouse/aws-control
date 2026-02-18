# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## First Steps

**Your first tool call in this repository MUST be reading
.claude/CODING_STANDARD.md. Do not read any other files, search, or take any
actions until you have read it.**
This contains InfraHouse's comprehensive coding standards for Terraform,
Python, and general formatting rules.

## Project Overview

This is the **aws-control** repository for InfraHouse — a Terraform
configuration managing core AWS infrastructure in the control account
(990466748045). It defines IAM users, roles, groups, policies, AWS SSO
(Identity Center) configuration, backup infrastructure, and cost alerts.

## Common Commands

```bash
make bootstrap       # Set up local dev environment (installs hooks + pip deps)
make lint            # Check code style (yamllint + terraform fmt -check)
make format          # Auto-format Terraform files
make plan            # terraform init + plan with configuration.tfvars
make apply           # terraform apply from saved plan (tf.plan)
```

## Architecture

**Terraform state** is stored in S3 (`infrahouse-aws-control-990466748045`)
in a separate account (289256138624) with DynamoDB locking. All providers
assume a role in the control account.

**Multi-region providers**: The default provider targets `us-west-1`. Named
aliases follow the pattern `aws-{account_id}-{region_code}` (e.g.,
`aws-990466748045-uw1`, `aws-990466748045-uw2`, `aws-990466748045-ue1`).

**Key resource groups**:
- **IAM**: Users, roles, assume-role policies, OIDC provider for GitHub
  Actions
- **AWS SSO**: Identity Store groups and users via AWS Identity Center
- **Backups**: Custom module (`modules/backup/`) creating S3 buckets + IAM
  users; Synology Glacier vault
- **Cost alerts**: Daily cost threshold monitoring via
  `registry.infrahouse.com/infrahouse/cost-alert/aws`

**CI/CD** (GitHub Actions):
- **PR**: Lint, validate, plan, publish plan comment (`terraform-CI.yml`)
- **Merge**: Download saved plan, apply (`terraform-CD.yml`)
- Authentication uses OIDC (GitHub → AWS IAM role
  `ih-tf-aws-control-github`)

## Conventions

- Terraform version pinned in `.terraform-version` (currently 1.14.1)
- InfraHouse modules sourced from `registry.infrahouse.com`; HashiCorp
  modules from the public registry
- All versions pinned exactly (no ranges) for InfraHouse modules; `~>` for
  provider versions
- GitHub Actions dependency updates are disabled in Renovate — managed by
  the `github-control` repository
