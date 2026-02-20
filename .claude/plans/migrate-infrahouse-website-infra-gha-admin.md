# Plan: Migrate infrahouse-website-infra CI/CD to Centralized Pattern

## Context

infrahouse-website-infra manages the InfraHouse website infrastructure
(ALB, ASG, CDN) in account 493370826424. Its CI/CD roles are currently
split across two child repos:

- **aws-control-493370826424**: gha-admin v~> 1.0 creates `-github` +
  `-admin` roles in 493370826424
- **aws-control-289256138624**: state-manager v~> 1.0 creates
  `-state-manager` role, state-bucket v~> 2.0 creates S3 bucket
  `infrahouse-website-infra` (via `for_each`) in 289256138624

We're migrating to the centralized pattern: CI/CD roles, state bucket,
and SSM parameters managed from `aws-control`.

**User constraints:**
- OK to recreate roles/policies
- NOT OK to lose data (S3 state bucket contents must be preserved)
- OK to run `terraform import` / `terraform state rm`

## Current Resources

**In 493370826424** (managed by `aws-control-493370826424`):
- `ih-tf-infrahouse-website-infra-github` — OIDC role (gha-admin v1.0)
- `ih-tf-infrahouse-website-infra-admin` — admin role (gha-admin v1.0)
- GitHub OIDC provider (`module.github-connector`) — **stays**

**In 289256138624** (managed by `aws-control-289256138624`):
- S3 bucket `infrahouse-website-infra`
  (`module.buckets["infrahouse-website-infra"]`)
- `ih-tf-infrahouse-website-infra-state-manager`
  (`module.ih-tf-infrahouse-website-infra-state-manager`)
- Shared DynamoDB table `infrahouse-terraform-state-locks` — **stays**

**Hardcoded role ARNs in workflows** (not using GitHub Actions vars):
- CI/CD: `arn:aws:iam::493370826424:role/ih-tf-infrahouse-website-infra-github`
- State: `arn:aws:iam::289256138624:role/ih-tf-infrahouse-website-infra-state-manager`

## Changes in aws-control

### Step 1: Create new file `aws_iam_role.ih_tf_infrahouse_website_infra.tf`

```hcl
# State bucket for infrahouse-website-infra in the TF states account
module "state_bucket_infrahouse_website_infra" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-website-infra"
}

# CI/CD roles for infrahouse-website-infra
module "ih_tf_infrahouse_website_infra" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws.aws-493370826424-uw1
    aws.cicd     = aws.aws-493370826424-uw1
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "infrahouse-website-infra"
  state_bucket              = module.state_bucket_infrahouse_website_infra.bucket_name
  terraform_locks_table_arn = module.state_bucket_infrahouse_website_infra.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
}

# SSM parameters in 493370826424 for backend discovery
module "ci_cd_params_infrahouse_website_infra" {
  source = "./modules/ci-cd-params"
  providers = {
    aws = aws.aws-493370826424-uw1
  }
  repo_name              = "infrahouse-website-infra"
  state_bucket           = module.state_bucket_infrahouse_website_infra.bucket_name
  lock_table             = module.state_bucket_infrahouse_website_infra.lock_table_name
  state_manager_role_arn = module.ih_tf_infrahouse_website_infra.state_manager_role_arn
  github_role_arn        = module.ih_tf_infrahouse_website_infra.github_role_arn
  admin_role_arn         = module.ih_tf_infrahouse_website_infra.admin_role_arn
}
```

Notes:
- `gh_org_name = "infrahouse"` (repo is in infrahouse org)
- `aws` + `aws.cicd` point to 493370826424 (where OIDC + admin roles live)
- `aws.tfstates` points to 289256138624 (where state bucket lives)
- No `allowed_arns` needed — website-infra doesn't assume cross-account
  roles
- No `depends_on` needed — OIDC provider already exists in 493370826424
- SSM params go in 493370826424 (where website-infra providers read)

### Step 2: Init and import existing resources

```bash
terraform init

# --- S3 bucket (in 289256138624) ---
terraform import \
  'module.state_bucket_infrahouse_website_infra.aws_s3_bucket.state-bucket' \
  infrahouse-website-infra
terraform import \
  'module.state_bucket_infrahouse_website_infra.aws_s3_bucket_versioning.enabled' \
  infrahouse-website-infra
terraform import \
  'module.state_bucket_infrahouse_website_infra.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-website-infra
terraform import \
  'module.state_bucket_infrahouse_website_infra.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-website-infra
terraform import \
  'module.state_bucket_infrahouse_website_infra.aws_s3_bucket_policy.state-bucke' \
  infrahouse-website-infra

# --- IAM roles (in 493370826424) ---
terraform import \
  'module.ih_tf_infrahouse_website_infra.aws_iam_role.github' \
  ih-tf-infrahouse-website-infra-github
terraform import \
  'module.ih_tf_infrahouse_website_infra.aws_iam_role.admin' \
  ih-tf-infrahouse-website-infra-admin

# --- State-manager role (in 289256138624) ---
terraform import \
  'module.ih_tf_infrahouse_website_infra.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-infrahouse-website-infra-state-manager
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
- 5 SSM parameters created in 493370826424
- **0 destroys**

```bash
make apply
```

## Post-apply: Update infrahouse-website-infra

### Step 4: Read new DynamoDB table name

```bash
aws ssm get-parameter \
  --name "/terraform/infrahouse-website-infra/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

### Step 5: Update backend config

**File:** `terraform.tf` — change DynamoDB table:

```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-terraform-state-locks"
```

Then reinitialize:
```bash
cd /Users/aleks/code/infrahouse/infrahouse-website-infra
terraform init -reconfigure
terraform plan  # verify no unexpected changes
```

## Cleanup source repos

### Step 6: Remove from aws-control-493370826424

```bash
cd /Users/aleks/code/infrahouse/aws-control-493370826424

# Remove gha-admin module resources from state
terraform state rm 'module.ih-tf-infrahouse-website-infra-admin'
```

Then remove `module "ih-tf-infrahouse-website-infra-admin"` block from
`aws_iam_role.ih-tf-infrahouse-website-infra.tf`. Also remove the two
website-infra outputs from `outputs.tf`.

### Step 7: Remove from aws-control-289256138624

```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624

# Remove state bucket from state
terraform state rm \
  'module.buckets["infrahouse-website-infra"]'

# Remove state-manager from state
terraform state rm \
  'module.ih-tf-infrahouse-website-infra-state-manager'
```

Then:
- Remove `"infrahouse-website-infra"` from `local.state_buckets`
- Remove `module "ih-tf-infrahouse-website-infra-state-manager"` block
- If `local.state_buckets` becomes empty, remove the `module "buckets"`
  block entirely
- If no other repos use `infrahouse-terraform-state-locks`, consider
  removing the shared DynamoDB table too

Apply both child repos to verify clean state.

## Files Modified

| Repository | File | Action |
|------------|------|--------|
| aws-control | `aws_iam_role.ih_tf_infrahouse_website_infra.tf` | **New**: state-bucket + gha-admin + ci-cd-params |
| infrahouse-website-infra | `terraform.tf` | Update DynamoDB table name |
| aws-control-493370826424 | `aws_iam_role.ih-tf-infrahouse-website-infra.tf` | Remove gha-admin module |
| aws-control-493370826424 | `outputs.tf` | Remove website-infra outputs |
| aws-control-289256138624 | `aws_s3_bucket.tf` | Remove website-infra from state_buckets |
| aws-control-289256138624 | `aws_iam_role.ih-tf-infrahouse-website-infra.tf` | Remove state-manager module |

## Key Risks and Mitigations

- **Role names unchanged** — `repo_name = "infrahouse-website-infra"`
  preserves all role names (`ih-tf-infrahouse-website-infra-*`)
- **State bucket preserved** — imported, not recreated
- **DynamoDB table changes** — website-infra gets its own dedicated
  table instead of shared `infrahouse-terraform-state-locks`. Backend
  config updated. State file in S3 is unaffected
- **gha-admin upgrade (1.0 -> 3.6.1)** — trust policies and IAM
  policies updated. Role names stay the same
- **Hardcoded workflow ARNs stay valid** — role names don't change,
  no workflow updates needed
- **Shared DynamoDB table** — remains in aws-control-289256138624
  until explicitly cleaned up

## Verification

1. aws-control: `terraform plan` after imports — no destroys
2. aws-control: `terraform apply` succeeds
3. SSM parameters queryable in 493370826424
4. infrahouse-website-infra: `terraform init -reconfigure` with new
   DynamoDB table
5. infrahouse-website-infra: `terraform plan` — no unexpected changes
6. infrahouse-website-infra: CI/CD works end-to-end after merge
7. aws-control-493370826424: `terraform plan` — clean after state rm
8. aws-control-289256138624: `terraform plan` — clean after state rm
