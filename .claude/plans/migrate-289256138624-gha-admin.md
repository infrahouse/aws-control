# Plan: Migrate AWS Account 289256138624 to Centralized CI/CD Pattern

## Context

Account 289256138624 (terraform-control / TF states account) currently has
its CI/CD roles managed within itself:
- `aws-control-289256138624` — gha-admin v1.0.1 creates `-github` +
  `-admin` roles, standalone state-manager v1.4.2 creates `-state-manager`
  role
- State bucket `infrahouse-aws-control-289256138624` managed by
  `module.buckets` for_each in the same repo

We're migrating to the centralized pattern: CI/CD roles, state bucket,
and SSM parameters managed from `aws-control`.

**This account is unique:** all three gha-admin providers (`aws`,
`aws.cicd`, `aws.tfstates`) point to the same account (289256138624),
since the state bucket lives in the same account as the CI/CD roles.

**User constraints:**
- OK to recreate roles/policies
- NOT OK to lose data (S3 state bucket contents must be preserved)
- OK to run `terraform import` / `terraform state rm`

**Decisions:**
- OIDC provider stays in child repo (already exists, child repo still
  active)
- State bucket imported into aws-control
- Shared DynamoDB table `infrahouse-terraform-state-locks` stays in
  aws-control-289256138624 (still used by 493370826424 and
  infrahouse-website-infra)

## Current Resources

**In 289256138624** (managed by `aws-control-289256138624`):
- `ih-tf-aws-control-289256138624-github` — OIDC role (gha-admin v1.0.1)
- `ih-tf-aws-control-289256138624-admin` — admin role (gha-admin v1.0.1)
- `ih-tf-aws-control-289256138624-state-manager` — standalone
  state-manager v1.4.2
- S3 bucket `infrahouse-aws-control-289256138624`
  (`module.buckets["infrahouse-aws-control-289256138624"]`)
- GitHub OIDC provider (`module.github-connector`) — **stays**
- Shared DynamoDB table `infrahouse-terraform-state-locks` — **stays**
- `ih-tf-github-control` role — **stays**
- `ih-tf-terraform-control` role — **stays**
- State-managers for 493370826424 and website-infra — **stay**
- State buckets for 493370826424 and website-infra — **stay**

**References to role names:**
- `providers.tf` — assumes `ih-tf-aws-control-289256138624-admin`
- `terraform.tf` — backend assumes
  `ih-tf-aws-control-289256138624-state-manager`
- `.github/workflows/terraform-CI.yml` — assumes
  `ih-tf-aws-control-289256138624-github`
- `.github/workflows/terraform-CD.yml` — assumes
  `ih-tf-aws-control-289256138624-github`

All references stay valid since `repo_name = "aws-control-289256138624"`
preserves role names.

## Changes in aws-control

### Step 1: Add state-bucket + gha-admin + ci-cd-params

**New file:** `aws_iam_role.ih_tf_aws_control_289256138624.tf`

```hcl
# State bucket for aws-control-289256138624 in the TF states account
module "state_bucket_289256138624" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-289256138624"
}

# CI/CD roles for aws-control-289256138624
module "ih_tf_aws_control_289256138624" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-289256138624-uw1
    aws.cicd     = aws.aws-289256138624-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control-289256138624"
  state_bucket              = module.state_bucket_289256138624.bucket_name
  terraform_locks_table_arn = module.state_bucket_289256138624.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
    "arn:aws:iam::493370826424:role/ih-tf-aws-control-493370826424-github",
  ]
}

# SSM parameters in 289256138624 for backend discovery
module "ci_cd_params_289256138624" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  repo_name              = "aws-control-289256138624"
  state_bucket           = module.state_bucket_289256138624.bucket_name
  lock_table             = module.state_bucket_289256138624.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_289256138624.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_289256138624.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_289256138624.admin_role_arn
}
```

Notes:
- All three providers point to `aws.aws-289256138624-uw1` (unique: this
  account IS the TF states account)
- `trusted_arns` includes SSO admin and 493370826424's github role
  (matching current `admin_allowed_arns`)
- No `allowed_arns` needed — this repo doesn't assume cross-account roles
- No `github_connector` needed — OIDC provider already exists in
  289256138624 (managed by child repo)
- No `depends_on` needed for OIDC — it's managed externally

## Import + Apply

### Step 2: Init and import existing resources

```bash
terraform init

# --- S3 bucket (in 289256138624) ---
terraform import \
  'module.state_bucket_289256138624.aws_s3_bucket.state-bucket' \
  infrahouse-aws-control-289256138624
terraform import \
  'module.state_bucket_289256138624.aws_s3_bucket_versioning.enabled' \
  infrahouse-aws-control-289256138624
terraform import \
  'module.state_bucket_289256138624.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-aws-control-289256138624
terraform import \
  'module.state_bucket_289256138624.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-aws-control-289256138624
terraform import \
  'module.state_bucket_289256138624.aws_s3_bucket_policy.state-bucke' \
  infrahouse-aws-control-289256138624

# --- IAM roles (in 289256138624) ---
terraform import \
  'module.ih_tf_aws_control_289256138624.aws_iam_role.github' \
  ih-tf-aws-control-289256138624-github
terraform import \
  'module.ih_tf_aws_control_289256138624.aws_iam_role.admin' \
  ih-tf-aws-control-289256138624-admin
terraform import \
  'module.ih_tf_aws_control_289256138624.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-aws-control-289256138624-state-manager
```

Policies are NOT imported — the module creates new policies with
`name_prefix`. Old policies stay attached temporarily.

### Step 3: Plan and apply

```bash
make plan
```

Expected plan:
- S3 bucket: tag updates
- New DynamoDB table created (random suffix, in 289256138624)
- Role trust policies updated to match v3.6.1
- New IAM policies created + attached to roles
- 5 SSM parameters created
- **0 destroys** (old policies are not in aws-control's state)

```bash
make apply
```

## Post-apply: Update child repo

### Step 4: Update child repo backend config

Read the new DynamoDB table name:
```bash
aws ssm get-parameter \
  --name "/terraform/aws-control-289256138624/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

In `aws-control-289256138624/terraform.tf`, change:
```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-terraform-state-locks"
```

Then reinitialize:
```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624
terraform init -reconfigure
terraform plan  # verify changes (may show updates from removing old modules)
```

## Cleanup aws-control-289256138624

### Step 5: Remove migrated resources from aws-control-289256138624

```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624

# Remove gha-admin module resources from state
terraform state rm 'module.ih-tf-aws-control-289256138624-admin'

# Remove state-manager module resources from state
terraform state rm 'module.ih-tf-aws-control-289256138624-state-manager'

# Remove state bucket from state
terraform state rm \
  'module.buckets["infrahouse-aws-control-289256138624"]'
```

Then remove from code:
- `aws_iam_role.ih-tf-aws-control-289256138624.tf` — **delete entire
  file** (gha-admin + state-manager modules)
- `aws_s3_bucket.tf` — remove `"infrahouse-aws-control-289256138624"`
  entry from `local.state_buckets`

Keep in aws-control-289256138624:
- `module.github-connector` (OIDC provider)
- `aws_dynamodb_table.terraform_locks` (shared, still used by
  493370826424 and website-infra)
- `module.buckets["infrahouse-aws-control-493370826424"]`
- `module.buckets["infrahouse-website-infra"]`
- `module.ih-tf-aws-control-493370826424-state-manager`
- `module.ih-tf-infrahouse-website-infra-state-manager`
- `aws_iam_role.ih-tf-github-control`
- `aws_iam_role.ih-tf-terraform-control`
- `data_sources.tf`

Apply to verify clean state:
```bash
terraform plan  # expect no changes
```

### Step 6: Clean up orphaned policies (optional, later)

Old policies with `name_prefix` in 289256138624 are no longer managed
but still attached. Detach and delete them manually via AWS Console or
CLI when convenient.

## Files Modified in aws-control

| File | Action |
|------|--------|
| `aws_iam_role.ih_tf_aws_control_289256138624.tf` | New: state-bucket + gha-admin + ci-cd-params |

No other files need changes — provider `aws-289256138624-uw1` already
exists in `providers.tf`.

## Key Risks and Mitigations

- **CI/CD role names unchanged** —
  `ih-tf-aws-control-289256138624-github`, `-admin`, `-state-manager`
  all keep their names. No workflow changes needed.
- **State bucket preserved** — imported, not recreated. Data safe.
- **Shared DynamoDB table unaffected** — stays in aws-control-289256138624,
  still used by 493370826424 and infrahouse-website-infra.
- **OIDC provider stays in child repo** — gha-admin v3.6.1 looks it up
  via data source. No conflict.
- **admin role trusts 493370826424 github role** — preserved via
  `trusted_arns`, matching current `admin_allowed_arns`.

## Verification

1. `terraform plan` after imports — no destroys
2. `terraform apply` succeeds
3. SSM parameters queryable in 289256138624
4. Child repo `terraform init -reconfigure` succeeds with new DynamoDB
   table
5. Child repo `terraform plan` shows expected changes (removed modules)
6. Child repo CI/CD (open PR + merge) works end-to-end