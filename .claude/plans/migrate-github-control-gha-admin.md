# Plan: Migrate github-control CI/CD to Centralized Pattern in aws-control

## Context

github-control currently self-manages its CI/CD infrastructure via the
`terraform-aws-ci-cd` module (v1.0.3, wrapping gha-admin ~> 3.2).
This creates the state bucket, DynamoDB lock table, and IAM roles
(github, admin, state-manager) within github-control's own Terraform
state.

All other repos (aws-control-289256138624, aws-control-303467602807,
aws-control-493370826424, aws-control-338531211565) have already been
migrated to the centralized pattern where aws-control manages their
CI/CD infrastructure using gha-admin v3.6.1 directly.

**Goal:** Migrate github-control to match, so all CI/CD infrastructure
is managed centrally from aws-control.

## Current Resources (github-control state)

**In 303467602807** (CI/CD account):
- `ih-tf-github-control-github` - OIDC role
- `ih-tf-github-control-admin` - admin role

**In 289256138624** (TF states account):
- S3 bucket `infrahouse-github-control-state`
- DynamoDB table `infrahouse-github-control-state-polished-lioness`
- `ih-tf-github-control-state-manager` - state manager role

**GitHub Actions variables** (separate resources in github-control):
- `role_admin`, `role_github`, `role_state_manager`,
  `state_bucket`, `dynamodb_lock_table_name`

## Changes in aws-control

### Step 1: Create new file `aws_iam_role.ih_tf_github_control.tf`

```hcl
# State bucket for github-control in the TF states account
module "state_bucket_github_control" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-github-control-state"
}

# CI/CD roles for github-control
module "ih_tf_github_control" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-303467602807-uw1
    aws.cicd     = aws.aws-303467602807-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse8"
  repo_name                 = "github-control"
  state_bucket              = module.state_bucket_github_control.bucket_name
  terraform_locks_table_arn = module.state_bucket_github_control.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
  allowed_arns = [
    "arn:aws:iam::289256138624:role/ih-tf-aws-control-289256138624-admin",
    "arn:aws:iam::493370826424:role/ih-tf-aws-control-493370826424-admin",
  ]
}

# SSM parameters in 303467602807 for backend discovery
module "ci_cd_params_github_control" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-303467602807-uw1
  }
  repo_name              = "github-control"
  state_bucket           = module.state_bucket_github_control.bucket_name
  lock_table             = module.state_bucket_github_control.lock_table_name
  state_manager_role_arn = module.ih_tf_github_control.state_manager_role_arn
  github_role_arn        = module.ih_tf_github_control.github_role_arn
  admin_role_arn         = module.ih_tf_github_control.admin_role_arn
}
```

Notes:
- `gh_org_name = "infrahouse8"` (repo is in infrahouse8 org)
- `aws` + `aws.cicd` point to 303467602807 (where OIDC + admin roles live)
- `aws.tfstates` points to 289256138624 (where state bucket lives)
- `allowed_arns` matches the current ci-cd module config
- SSM params go in 303467602807 (where github-control's providers read them)
- No `depends_on` for github_connector needed - OIDC provider already
  exists in 303467602807

### Step 2: Init and import existing resources

```bash
terraform init

# --- S3 bucket (in 289256138624) ---
terraform import \
  'module.state_bucket_github_control.aws_s3_bucket.state-bucket' \
  infrahouse-github-control-state
terraform import \
  'module.state_bucket_github_control.aws_s3_bucket_versioning.enabled' \
  infrahouse-github-control-state
terraform import \
  'module.state_bucket_github_control.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-github-control-state
terraform import \
  'module.state_bucket_github_control.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-github-control-state
terraform import \
  'module.state_bucket_github_control.aws_s3_bucket_policy.state-bucke' \
  infrahouse-github-control-state

# --- IAM roles (in 303467602807) ---
terraform import \
  'module.ih_tf_github_control.aws_iam_role.github' \
  ih-tf-github-control-github
terraform import \
  'module.ih_tf_github_control.aws_iam_role.admin' \
  ih-tf-github-control-admin

# --- State-manager role (in 289256138624) ---
terraform import \
  'module.ih_tf_github_control.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-github-control-state-manager
```

### Step 3: Plan and apply

```bash
make plan
```

Expected plan:
- S3 bucket: tag updates only
- New DynamoDB table created (random suffix, in 289256138624)
- Role trust policies updated to match gha-admin v3.6.1
- New IAM policies created + attached to roles
- 5 SSM parameters created in 303467602807
- **0 destroys**

```bash
make apply
```

## Changes in github-control

### Step 4: Read new DynamoDB table name

```bash
aws ssm get-parameter \
  --name "/terraform/github-control/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

### Step 5: Update backend config

**File:** `terraform.tf` - change DynamoDB table:

```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-github-control-state-polished-lioness"
```

### Step 6: Remove ci-cd module, update variable references

**File:** `infrahouse8_repos.tf`

Remove `module "infrahouse8-github-control"` (lines 52-69).

Add SSM data sources and update the 5 GitHub Actions variable
resources to read from SSM:

```hcl
data "aws_ssm_parameter" "github_control_admin_role" {
  provider = aws.aws-303467602807-uw1
  name     = "/terraform/github-control/ci-cd/admin_role_arn"
}

data "aws_ssm_parameter" "github_control_github_role" {
  provider = aws.aws-303467602807-uw1
  name     = "/terraform/github-control/ci-cd/github_role_arn"
}

data "aws_ssm_parameter" "github_control_state_manager_role" {
  provider = aws.aws-303467602807-uw1
  name     = "/terraform/github-control/backend/state_manager_role_arn"
}

data "aws_ssm_parameter" "github_control_state_bucket" {
  provider = aws.aws-303467602807-uw1
  name     = "/terraform/github-control/backend/state_bucket"
}

data "aws_ssm_parameter" "github_control_lock_table" {
  provider = aws.aws-303467602807-uw1
  name     = "/terraform/github-control/backend/lock_table"
}

resource "github_actions_variable" "role_admin" {
  provider      = github.infrahouse8
  repository    = module.ih_8_repos["github-control"].repo_name
  value         = data.aws_ssm_parameter.github_control_admin_role.value
  variable_name = "role_admin"
}

resource "github_actions_variable" "role_github" {
  provider      = github.infrahouse8
  repository    = module.ih_8_repos["github-control"].repo_name
  value         = data.aws_ssm_parameter.github_control_github_role.value
  variable_name = "role_github"
}

resource "github_actions_variable" "role_state_manager" {
  provider      = github.infrahouse8
  repository    = module.ih_8_repos["github-control"].repo_name
  value         = data.aws_ssm_parameter.github_control_state_manager_role.value
  variable_name = "role_state_manager"
}

resource "github_actions_variable" "state_bucket" {
  provider      = github.infrahouse8
  repository    = module.ih_8_repos["github-control"].repo_name
  value         = data.aws_ssm_parameter.github_control_state_bucket.value
  variable_name = "state_bucket"
}

resource "github_actions_variable" "dynamodb_lock_table_name" {
  provider      = github.infrahouse8
  repository    = module.ih_8_repos["github-control"].repo_name
  value         = data.aws_ssm_parameter.github_control_lock_table.value
  variable_name = "dynamodb_lock_table_name"
}
```

### Step 7: State rm and reinitialize

```bash
cd /Users/aleks/code/infrahouse/github-control

# Remove the old module from state (no destroy)
terraform state rm 'module.infrahouse8-github-control'

# Reinitialize with new backend config
terraform init -reconfigure

# Plan - should show:
#   - Module removal (0 destroys, already state rm'd)
#   - GitHub Actions variables updated (new values from SSM)
#   - Data sources added
terraform plan
```

### Step 8: Apply github-control (via PR)

Create a PR with the changes from steps 5-6. The CI will:
1. Init with new backend config (new DynamoDB table)
2. Plan should show variable value updates only
3. Merge and apply

## Files Modified

| Repository | File | Action |
|------------|------|--------|
| aws-control | `aws_iam_role.ih_tf_github_control.tf` | **New**: state-bucket + gha-admin + ci-cd-params |
| github-control | `terraform.tf` | Update DynamoDB table name |
| github-control | `infrahouse8_repos.tf` | Remove ci-cd module, add SSM data sources, update variable refs |

## Key Risks and Mitigations

- **Role names unchanged** - `repo_name = "github-control"` preserves
  all role names (`ih-tf-github-control-*`)
- **State bucket preserved** - imported, not recreated
- **DynamoDB table changes** - old table orphaned, new one created.
  Backend config updated. State file in S3 is unaffected
- **GitHub Actions variables** - updated in same PR, no CI/CD
  disruption after merge
- **Cross-account access preserved** - `allowed_arns` matches current
  ci-cd module config (289256138624 + 493370826424 admin roles)
- **gha-admin upgrade (3.2 -> 3.6.1)** - may update role trust
  policies and IAM policies. Role names stay the same

## Verification

1. aws-control: `terraform plan` after imports shows no destroys
2. aws-control: `terraform apply` succeeds
3. SSM parameters queryable in 303467602807
4. github-control: `terraform init -reconfigure` with new DynamoDB table
5. github-control: `terraform plan` shows expected changes (variable
   updates, module removal)
6. github-control: CI/CD works end-to-end after merge