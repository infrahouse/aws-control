# Plan: Migrate AWS Account 493370826424 to Centralized CI/CD Pattern

## Context

Account 493370826424 currently has its CI/CD roles managed within
itself:
- `aws-control-493370826424` — gha-admin v1.0.1 creates `-github` +
  `-admin` roles in 493370826424
- `aws-control-289256138624` — state-manager v1.4.2 creates
  `-state-manager` role, state-bucket creates S3 bucket
  `infrahouse-aws-control-493370826424` (via `for_each`) in 289256138624

We're migrating to the centralized pattern: CI/CD roles, state bucket,
and SSM parameters managed from `aws-control`.

**User constraints:**
- OK to recreate roles/policies
- NOT OK to lose data (S3 state bucket contents must be preserved)
- OK to run `terraform import` / `terraform state rm`

**Decisions:**
- OIDC provider stays in child repo (already exists, child repo still
  active)
- State bucket imported into aws-control
- infrahouse-website-infra roles stay in child repo for now (already
  at gha-admin v3.6.1)

## Current Resources

**In 493370826424** (managed by `aws-control-493370826424`):
- `ih-tf-aws-control-493370826424-github` — OIDC role (gha-admin v1.0.1)
- `ih-tf-aws-control-493370826424-admin` — admin role (gha-admin v1.0.1)
  - Trusts: `arn:aws:iam::990466748045:user/aleks`,
    `arn:aws:iam::303467602807:role/ih-tf-github-control-github`
- `ih-tf-infrahouse-website-infra-github/admin/state-manager` — website
  infra roles (gha-admin v3.6.1) — **out of scope, stays in child repo
  for now**
- GitHub OIDC provider (`module.github-connector`) — **stays**
- Various other roles (puppet, toolkit, osv-scanner, registry, etc.) —
  **stay**

**In 289256138624** (managed by `aws-control-289256138624`):
- S3 bucket `infrahouse-aws-control-493370826424`
  (`module.buckets["infrahouse-aws-control-493370826424"]`)
- `ih-tf-aws-control-493370826424-state-manager`
  (`module.ih-tf-aws-control-493370826424-state-manager`)
- Shared DynamoDB table `infrahouse-terraform-state-locks` — **stays**

**Cross-account access in child repo providers:**
- `aws-289256138624-uw1` — assumes state-manager role (for backend)
- `aws-303467602807-uw1` — assumes
  `ih-tf-aws-control-303467602807-read-only` (for remote state/DNS)
- Remote state reads 303467602807 state via
  `ih-tf-aws-control-303467602807-state-manager-read-only` in
  289256138624

**References to role names:**
- `providers.tf` — assumes `ih-tf-aws-control-493370826424-admin`
- `terraform.tf` — backend assumes
  `ih-tf-aws-control-493370826424-state-manager`
- `.github/workflows/*.yml` — assumes
  `ih-tf-aws-control-493370826424-github`

All references stay valid since
`repo_name = "aws-control-493370826424"` preserves role names.

## Changes in aws-control

### Step 0: Add 493370826424 to allowed_arns in 990466748045

**File:** `aws_iam_role.ih_tf_aws_control_990466748045.tf`

```hcl
allowed_arns = [
  "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
  "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
  "arn:aws:iam::303467602807:role/AWSControlTowerExecution",
  "arn:aws:iam::493370826424:role/AWSControlTowerExecution",
]
```

### Step 1: Add provider for 493370826424

**File:** `providers.tf`

```hcl
provider "aws" {
  alias  = "aws-493370826424-uw1"
  region = "us-west-1"
  assume_role {
    role_arn = "arn:aws:iam::493370826424:role/AWSControlTowerExecution"
  }
  default_tags {
    tags = local.default_tags
  }
}
```

### Step 2: Add state-bucket + gha-admin + ci-cd-params

**New file:** `aws_iam_role.ih_tf_aws_control_493370826424.tf`

```hcl
# State bucket for aws-control-493370826424 in the TF states account
module "state_bucket_493370826424" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-493370826424"
}

# CI/CD roles for aws-control-493370826424
module "ih_tf_aws_control_493370826424" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-493370826424-uw1
    aws.cicd     = aws.aws-493370826424-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-493370826424"
  state_bucket              = module.state_bucket_493370826424.bucket_name
  terraform_locks_table_arn = module.state_bucket_493370826424.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
    "arn:aws:iam::303467602807:role/ih-tf-github-control-github",
  ]
  allowed_arns = [
    "arn:aws:iam::289256138624:role/ih-tf-aws-control-303467602807-state-manager-read-only",
    "arn:aws:iam::303467602807:role/ih-tf-aws-control-303467602807-read-only",
  ]
}

# SSM parameters in 493370826424 for backend discovery
module "ci_cd_params_493370826424" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-493370826424-uw1
  }
  repo_name              = "aws-control-493370826424"
  state_bucket           = module.state_bucket_493370826424.bucket_name
  lock_table             = module.state_bucket_493370826424.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_493370826424.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_493370826424.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_493370826424.admin_role_arn
}
```

Notes:
- `aws` and `aws.cicd` point to 493370826424 (roles created there)
- `aws.tfstates` points to 289256138624 (state bucket + state-manager
  live there)
- `trusted_arns` replaces old `admin_allowed_arns`:
  - SSO admin (replaces IAM user `aleks`)
  - github-control role from 303467602807 (still needed)
- `allowed_arns` for cross-account access the child repo needs:
  - Read-only state-manager for 303467602807 state in 289256138624
  - Read-only role in 303467602807 (for Route53 data source)
- No `github_connector` needed — OIDC provider already exists in
  493370826424 (managed by child repo)

## Import + Apply

### Step 3: Init and import existing resources

```bash
terraform init

# --- S3 bucket (in 289256138624) ---
terraform import \
  'module.state_bucket_493370826424.aws_s3_bucket.state-bucket' \
  infrahouse-aws-control-493370826424
terraform import \
  'module.state_bucket_493370826424.aws_s3_bucket_versioning.enabled' \
  infrahouse-aws-control-493370826424
terraform import \
  'module.state_bucket_493370826424.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-aws-control-493370826424
terraform import \
  'module.state_bucket_493370826424.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-aws-control-493370826424
terraform import \
  'module.state_bucket_493370826424.aws_s3_bucket_policy.state-bucke' \
  infrahouse-aws-control-493370826424

# --- IAM roles (in 493370826424) ---
terraform import \
  'module.ih_tf_aws_control_493370826424.aws_iam_role.github' \
  ih-tf-aws-control-493370826424-github
terraform import \
  'module.ih_tf_aws_control_493370826424.aws_iam_role.admin' \
  ih-tf-aws-control-493370826424-admin

# --- State-manager role (in 289256138624) ---
terraform import \
  'module.ih_tf_aws_control_493370826424.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-aws-control-493370826424-state-manager
```

### Step 4: Plan and apply

```bash
make plan
```

Expected plan:
- S3 bucket: tag updates
- New DynamoDB table created (random suffix, in 289256138624)
- Role trust policies updated to match v3.6.1
- New IAM policies created + attached to roles
- 5 SSM parameters created
- Cross-account policy updated (493370826424 added to allowed_arns)
- **0 destroys**

```bash
make apply
```

## Post-apply: Update child repo

### Step 5: Update child repo backend config

Read the new DynamoDB table name:
```bash
aws ssm get-parameter \
  --name "/terraform/aws-control-493370826424/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

In `aws-control-493370826424/terraform.tf`, change:
```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-terraform-state-locks"
```

Then reinitialize:
```bash
cd /Users/aleks/code/infrahouse/aws-control-493370826424
terraform init -reconfigure
terraform plan  # verify changes
```

## Cleanup source repos

### Step 6: Remove from aws-control-493370826424

```bash
cd /Users/aleks/code/infrahouse/aws-control-493370826424

# Remove gha-admin module resources from state
terraform state rm 'module.ih-tf-aws-control-493370826424-admin'
```

Then remove the `module "ih-tf-aws-control-493370826424-admin"` block
from `aws_iam_role.ih-tf-aws-control-493370826424.tf`. Also update
`outputs.tf` — the `gha_role_arn` and `admin_role_arn` outputs
reference the old module. Either remove them or update to use the
SSM-discovered ARNs.

Keep in aws-control-493370826424:
- `module.github-connector` (OIDC provider)
- `module.ih-tf-infrahouse-website-infra-admin` (gha-admin v3.6.1 —
  separate migration later)
- All other roles (puppet, toolkit, registry, etc.)
- All infrastructure (VPC, DNS, ECR, registry, jumphost, etc.)

### Step 7: Remove from aws-control-289256138624

```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624

# Remove state bucket from state
terraform state rm \
  'module.buckets["infrahouse-aws-control-493370826424"]'

# Remove state-manager from state
terraform state rm \
  'module.ih-tf-aws-control-493370826424-state-manager'
```

Then:
- Remove `"infrahouse-aws-control-493370826424"` from
  `local.state_buckets`
- Remove `module.ih-tf-aws-control-493370826424-state-manager` block

Apply both repos to verify clean state.

## Files Modified in aws-control

| File | Action |
|------|--------|
| `providers.tf` | Add `aws-493370826424-uw1` |
| `aws_iam_role.ih_tf_aws_control_493370826424.tf` | New: state-bucket + gha-admin + ci-cd-params |
| `aws_iam_role.ih_tf_aws_control_990466748045.tf` | Add 493370826424 to `allowed_arns` |

## Key Risks and Mitigations

- **CI/CD role names unchanged** — all role names preserved via
  `repo_name = "aws-control-493370826424"`
- **State bucket preserved** — imported, not recreated
- **Cross-account access preserved** — `allowed_arns` includes the two
  roles needed for remote state reads and Route53 access
- **admin trust changes** — `user/aleks` replaced by SSO admin role.
  SSO admin is the correct modern approach (IAM user is legacy)
- **github-control trust preserved** — 303467602807's
  `ih-tf-github-control-github` stays in `trusted_arns`
- **infrahouse-website-infra untouched** — already at gha-admin v3.6.1
  in child repo; separate migration later if desired

## Verification

1. `terraform plan` after imports — no destroys
2. `terraform apply` succeeds
3. SSM parameters queryable in 493370826424
4. Child repo `terraform init -reconfigure` with new DynamoDB table
5. Child repo `terraform plan` shows expected changes
6. Child repo CI/CD works end-to-end