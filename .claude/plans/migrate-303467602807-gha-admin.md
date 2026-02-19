# Plan: Migrate AWS Account 303467602807 to Centralized CI/CD Pattern

## Context

Account 303467602807 (CI/CD account) currently has its CI/CD roles managed
across two repos:
- `aws-control-303467602807` — gha-admin v~1.0 creates `-github` + `-admin`
  roles in 303467602807
- `aws-control-289256138624` — state-manager v~1.0 creates `-state-manager`
  role, state-bucket v~2.0 creates S3 bucket (via `for_each`) in 289256138624

We're migrating to the centralized pattern established with 338531211565:
all CI/CD roles, state bucket, and SSM parameters managed from `aws-control`.

**User constraints:**
- OK to recreate roles/policies
- NOT OK to lose data (S3 state bucket contents must be preserved)
- OK to run `terraform import` / `terraform state rm`

**Decisions:**
- Read-only roles stay in current repos (`-read-only` in 303467602807,
  `-state-manager-read-only` in 289256138624)
- State bucket imported into aws-control
- OIDC provider stays in child repo (already exists, child repo still active)

## Current Resources

**In 303467602807** (managed by `aws-control-303467602807`):
- `ih-tf-aws-control-303467602807-github` — OIDC role
- `ih-tf-aws-control-303467602807-admin` — admin role
- `ih-tf-aws-control-303467602807-read-only` — **stays**
- GitHub OIDC provider (`module.github-connector`) — **stays**

**In 289256138624** (managed by `aws-control-289256138624`):
- S3 bucket `infrahouse-aws-control-303467602807`
  (`module.buckets["infrahouse-aws-control-303467602807"]`)
- `ih-tf-aws-control-303467602807-state-manager`
  (`module.ih-tf-aws-control-303467602807-state-manager`)
- `ih-tf-aws-control-303467602807-state-manager-read-only` — **stays**
- Shared DynamoDB table `infrahouse-terraform-state-locks` — **stays**

## Changes in aws-control

### Step 1: Add provider for 303467602807

**File:** `providers.tf`

```hcl
provider "aws" {
  alias  = "aws-303467602807-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::303467602807:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}
```

### Step 2: Add state-bucket + gha-admin + ci-cd-params

**New file:** `aws_iam_role.ih_tf_aws_control_303467602807.tf`

```hcl
# State bucket for aws-control-303467602807 in the TF states account
module "state_bucket_303467602807" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-303467602807"
}

# CI/CD roles for aws-control-303467602807
module "ih_tf_aws_control_303467602807" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-303467602807-uw1
    aws.cicd     = aws.aws-303467602807-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-303467602807"
  state_bucket              = module.state_bucket_303467602807.bucket_name
  terraform_locks_table_arn = module.state_bucket_303467602807.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
}

# SSM parameters in 303467602807 for backend discovery
module "ci_cd_params_303467602807" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-303467602807-uw1
  }
  repo_name              = "aws-control-303467602807"
  state_bucket           = module.state_bucket_303467602807.bucket_name
  lock_table             = module.state_bucket_303467602807.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_303467602807.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_303467602807.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_303467602807.admin_role_arn
}
```

Note: No `github_connector` module needed — OIDC provider already exists in
303467602807 (managed by the child repo). The gha-admin module finds it via
`data.aws_iam_openid_connect_provider`.

### Step 3: Update cross-account policy

**File:** `aws_iam_policy.github_cross_account.tf`

Add 303467602807 to the Resource list:

```hcl
Resource = [
  "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
  "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
  "arn:aws:iam::303467602807:role/AWSControlTowerExecution",
]
```

## Import + Apply

### Step 4: Init and import existing resources

```bash
terraform init

# --- S3 bucket (in 289256138624) ---
terraform import \
  'module.state_bucket_303467602807.aws_s3_bucket.state-bucket' \
  infrahouse-aws-control-303467602807
terraform import \
  'module.state_bucket_303467602807.aws_s3_bucket_versioning.enabled' \
  infrahouse-aws-control-303467602807
terraform import \
  'module.state_bucket_303467602807.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-aws-control-303467602807
terraform import \
  'module.state_bucket_303467602807.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-aws-control-303467602807
terraform import \
  'module.state_bucket_303467602807.aws_s3_bucket_policy.state-bucke' \
  infrahouse-aws-control-303467602807

# --- IAM roles ---
terraform import \
  'module.ih_tf_aws_control_303467602807.aws_iam_role.github' \
  ih-tf-aws-control-303467602807-github
terraform import \
  'module.ih_tf_aws_control_303467602807.aws_iam_role.admin' \
  ih-tf-aws-control-303467602807-admin
terraform import \
  'module.ih_tf_aws_control_303467602807.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-aws-control-303467602807-state-manager
```

Policies are NOT imported — the module creates new policies and attaches them
alongside existing ones. Old policies stay attached temporarily (dual access
to both old shared DynamoDB table and new per-repo table during transition).

### Step 5: Plan and apply

```bash
make plan
```

Expected plan:
- S3 bucket: minor attribute updates (if any)
- New DynamoDB table created (random suffix)
- Role trust policies updated to match v3.6.1
- New IAM policies created + attached to roles
- 5 SSM parameters created
- Cross-account policy updated with 303467602807
- **0 destroys**

```bash
make apply
```

## Post-apply: Update child repo

### Step 6: Update child repo backend config

Read the new DynamoDB table name:
```bash
aws ssm get-parameter \
  --name "/terraform/aws-control-303467602807/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

In `aws-control-303467602807/terraform.tf`, change:
```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-terraform-state-locks"
```

Then reinitialize:
```bash
cd /Users/aleks/code/infrahouse/aws-control-303467602807
terraform init -reconfigure
terraform plan  # should show no changes
```

## Cleanup source repos

### Step 7: Remove from aws-control-303467602807

```bash
cd /Users/aleks/code/infrahouse/aws-control-303467602807

# Remove gha-admin module resources from state
terraform state rm 'module.ih-tf-aws-control-303467602807-admin'
```

Then remove the `module "ih-tf-aws-control-303467602807-admin"` block from
`aws_iam_role.ih-tf-aws-control-303467602807.tf`. Keep the read-only role
and `module.github-connector`.

### Step 8: Remove from aws-control-289256138624

```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624

# Remove state bucket from state
terraform state rm \
  'module.buckets["infrahouse-aws-control-303467602807"]'

# Remove state-manager from state
terraform state rm \
  'module.ih-tf-aws-control-303467602807-state-manager'
```

Then:
- Remove `"infrahouse-aws-control-303467602807"` from `local.state_buckets`
- Remove `module.ih-tf-aws-control-303467602807-state-manager` block
- Keep `module.ih-tf-aws-control-303467602807-state-manager-read-only`

Apply both repos to verify clean state (expect no changes).

### Step 9: Clean up orphaned policies (optional, later)

Old policies with `name_prefix` in 303467602807 and 289256138624 are no
longer managed but still attached. Detach and delete them manually via
AWS Console or CLI when convenient.

## Files Modified in aws-control

| File | Action |
|------|--------|
| `providers.tf` | Add `aws-303467602807-uw1` |
| `aws_iam_role.ih_tf_aws_control_303467602807.tf` | New: state-bucket + gha-admin + ci-cd-params |
| `aws_iam_policy.github_cross_account.tf` | Add 303467602807 to Resource list |

## Verification

1. `terraform plan` after imports — no destroys
2. `terraform apply` succeeds
3. SSM parameters queryable in 303467602807
4. Child repo `terraform init -reconfigure` succeeds with new DynamoDB table
5. Child repo `terraform plan` shows no changes
6. Child repo CI/CD (open PR + merge) works end-to-end