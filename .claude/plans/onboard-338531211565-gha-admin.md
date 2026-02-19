# Plan: Onboard AWS Account 338531211565 (Log Archive) via gha-admin v3.6.1

## Context

Account 338531211565 is a Log Archive account created by Control Tower. It's managed by Terraform
but doesn't have its own `aws-control-338531211565` repo yet. We're using this as the first test case
for centralizing CI/CD role management in the `aws-control` repo using `gha-admin` v3.6.1's
three-role architecture (github + admin + state-manager).

The gha-admin module requires:
- `aws` (default) — principal account where `-admin` role is created
- `aws.cicd` — account where `-github` role + OIDC provider live
- `aws.tfstates` — account where `-state-manager` role is created (289256138624)

For 338531211565, both `aws` and `aws.cicd` point to the same account (338531211565).
The `aws.tfstates` provider points to 289256138624. Both accounts have
`AWSControlTowerExecution` roles trusted by `990466748045:root`.

## Prerequisites (other repos, applied before this repo)

### 1. github-control — create the repo

**File:** `/Users/aleks/code/infrahouse/github-control/repos.tf`

Add to `local.repos`:
```hcl
"aws-control-338531211565" = {
  "description" = "InfraHouse Log Archive AWS Account 338531211565."
  "type"        = "terraform_aws"
}
```

## Changes in this repo (aws-control)

### Step 1: Add providers for 338531211565 and 289256138624

**File:** `providers.tf`

Append two new provider blocks:

```hcl
provider "aws" {
  alias  = "aws-338531211565-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::338531211565:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "aws-289256138624-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::289256138624:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}
```

### Step 2: Create state bucket for 338531211565 in 289256138624

**New file:** `state_bucket_338531211565.tf`

The `state-bucket` module creates both the S3 bucket and a DynamoDB lock table.
Its `lock_table_arn` output feeds directly into the gha-admin module.

```hcl
module "state_bucket_338531211565" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-338531211565"
}
```

### Step 3: Create OIDC provider + gha-admin module for 338531211565

**New file:** `aws_iam_role.ih_tf_aws_control_338531211565.tf`

The gha-admin v3.6.1 module expects an existing OIDC provider in the `aws.cicd` account
(looked up via `data "aws_iam_openid_connect_provider"`). Since 338531211565 is greenfield,
we must create the OIDC provider there first.

```hcl
# OIDC provider for GitHub Actions in 338531211565
module "github_connector_338531211565" {
  source  = "infrahouse/gh-identity-provider/aws"
  version = "1.1.1"
  providers = {
    aws = aws.aws-338531211565-uw1
  }
}

# CI/CD roles for aws-control-338531211565
module "ih_tf_aws_control_338531211565" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-338531211565-uw1
    aws.cicd     = aws.aws-338531211565-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-338531211565"
  state_bucket              = module.state_bucket_338531211565.bucket_name
  terraform_locks_table_arn = module.state_bucket_338531211565.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]

  depends_on = [module.github_connector_338531211565]
}
```

### Step 4: Allow ih-tf-aws-control-github to assume cross-account roles

The CI/CD pipeline runs as `ih-tf-aws-control-github`. Its IAM policy (managed by
gha-admin v1.0.1) only allows assuming `ih-tf-aws-control-admin` and
`ih-tf-aws-control-state-manager`. For the new providers to work in CI/CD, the github
role needs permission to assume `AWSControlTowerExecution` in both target accounts.

**New file:** `aws_iam_policy.github_cross_account.tf`

```hcl
# Allow the github role to assume AWSControlTowerExecution in managed accounts.
# This is a temporary bridge until we upgrade this repo's own gha-admin to v3.6.1,
# which supports the allowed_arns variable natively.

resource "aws_iam_policy" "github_cross_account" {
  name        = "ih-tf-aws-control-github-cross-account"
  description = "Allow ih-tf-aws-control-github to assume roles in managed accounts"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeControlTowerExecution"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
          "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_cross_account" {
  role       = "ih-tf-aws-control-github"
  policy_arn = aws_iam_policy.github_cross_account.arn
}
```

## Verification

1. Run `terraform init` (downloads gha-admin v3.6.1 + gh-identity-provider for 338531211565)
2. Run `make plan` locally (SSO credentials can assume AWSControlTowerExecution via :root trust)
3. Verify plan creates:
   - S3 state bucket + DynamoDB lock table in 289256138624
   - OIDC provider in 338531211565
   - `ih-tf-aws-control-338531211565-github` role in 338531211565
   - `ih-tf-aws-control-338531211565-admin` role in 338531211565
   - `ih-tf-aws-control-338531211565-state-manager` role in 289256138624
   - `ih-tf-aws-control-github-cross-account` IAM policy + attachment in 990466748045
4. Apply locally, then verify CI/CD works on a test PR

## Future steps (not part of this plan)

- Create the `aws-control-338531211565` repo content (terraform.tf, providers.tf, etc.)
- Migrate existing accounts (303467602807, 493370826424, etc.) from aws-control-289256138624
- Upgrade this repo's own gha-admin from v1.0.1 to v3.6.1 (replacing the cross-account policy with `allowed_arns`)
