# Plan: Upgrade aws-control's own gha-admin to v3.6.1 (990466748045)

## Context

The aws-control repo itself uses gha-admin v1.0.1 for its CI/CD roles in
990466748045. This creates `ih-tf-aws-control-github` and
`ih-tf-aws-control-admin` but not a state-manager role (that's managed
separately in aws-control-289256138624).

Upgrading to v3.6.1 brings the three-role architecture and replaces the
temporary `github_cross_account` policy with native `allowed_arns`.

**Key decision:** Keep `repo_name = "aws-control"` to preserve existing
role names (`ih-tf-aws-control-github`, `-admin`, `-state-manager`).

## Current State

**In aws-control state (990466748045):**
- `module.ih-tf-aws-control-990466748045-admin` — gha-admin v1.0.1
  - `aws_iam_role.github` → `ih-tf-aws-control-github`
  - `aws_iam_role.admin` → `ih-tf-aws-control-admin`
  - `aws_iam_policy.github`
  - `aws_iam_role_policy_attachment.github`
  - `aws_iam_role_policy_attachment.admin`
- `aws_iam_policy.github_cross_account` — temporary cross-account policy
- `aws_iam_role_policy_attachment.github_cross_account`
- `module.github_connector` — OIDC provider (stays)

**In 289256138624 (managed by aws-control-289256138624):**
- S3 bucket `infrahouse-aws-control-990466748045`
  (`module.buckets["infrahouse-aws-control-990466748045"]`)
- `ih-tf-aws-control-state-manager` role (standalone state-manager module)
- Shared DynamoDB table `infrahouse-terraform-state-locks`

**References to role names:**
- `providers.tf` — assumes `ih-tf-aws-control-admin`
- `terraform.tf` — backend assumes `ih-tf-aws-control-state-manager`
- `.github/workflows/terraform-CI.yml` — assumes `ih-tf-aws-control-github`
- `.github/workflows/terraform-CD.yml` — assumes `ih-tf-aws-control-github`
- `aws_iam_policy.github_cross_account.tf` — attached to
  `ih-tf-aws-control-github`

All references stay valid since `repo_name = "aws-control"` preserves names.

## Changes in aws-control

### Step 1: Replace gha-admin v1.0.1 with v3.6.1

**File:** `aws_iam_role.ih_tf_aws_control_990466748045.tf` (rewrite)

```hcl
# State bucket for aws-control in the TF states account
module "state_bucket_990466748045" {
  source  = "infrahouse/state-bucket/aws"
  version = "2.2.0"
  providers = {
    aws = aws.aws-289256138624-uw1
  }
  bucket = "infrahouse-aws-control-990466748045"
}

# CI/CD roles for aws-control (990466748045)
module "ih_tf_aws_control_990466748045" {
  source  = "infrahouse/gha-admin/aws"
  version = "3.6.1"
  providers = {
    aws          = aws
    aws.cicd     = aws
    aws.tfstates = aws.aws-289256138624-uw1
  }
  gh_org_name               = "infrahouse"
  repo_name                 = "aws-control"
  state_bucket              = module.state_bucket_990466748045.bucket_name
  terraform_locks_table_arn = module.state_bucket_990466748045.lock_table_arn
  trusted_arns = [
    tolist(data.aws_iam_roles.sso_admin.arns)[0],
  ]
  allowed_arns = [
    "arn:aws:iam::338531211565:role/AWSControlTowerExecution",
    "arn:aws:iam::289256138624:role/AWSControlTowerExecution",
    "arn:aws:iam::303467602807:role/AWSControlTowerExecution",
  ]

  depends_on = [module.github_connector]
}

# SSM parameters in 990466748045 for backend discovery
module "ci_cd_params_990466748045" {
  source = "./modules/ci-cd-params"
  repo_name              = "aws-control"
  state_bucket           = module.state_bucket_990466748045.bucket_name
  lock_table             = module.state_bucket_990466748045.lock_table_name
  state_manager_role_arn = module.ih_tf_aws_control_990466748045.state_manager_role_arn
  github_role_arn        = module.ih_tf_aws_control_990466748045.github_role_arn
  admin_role_arn         = module.ih_tf_aws_control_990466748045.admin_role_arn
}
```

Notes:
- `aws` and `aws.cicd` use the default provider (990466748045)
- `allowed_arns` replaces the cross-account policy
- `depends_on = [module.github_connector]` since OIDC provider is in
  this repo
- ci-cd-params uses default provider (no explicit providers block needed)

### Step 2: Delete cross-account policy

**Delete file:** `aws_iam_policy.github_cross_account.tf`

The `allowed_arns` in the gha-admin module now handles cross-account
assume permissions natively.

## State Operations (local, before plan)

### Step 3: Move existing resources to new module name

v1.0.1 and v3.6.1 share the same internal resource names for github and
admin roles, so `terraform state mv` works cleanly:

```bash
terraform init

# Move roles
terraform state mv \
  'module.ih-tf-aws-control-990466748045-admin.aws_iam_role.github' \
  'module.ih_tf_aws_control_990466748045.aws_iam_role.github'
terraform state mv \
  'module.ih-tf-aws-control-990466748045-admin.aws_iam_role.admin' \
  'module.ih_tf_aws_control_990466748045.aws_iam_role.admin'

# Move github policy and attachments
terraform state mv \
  'module.ih-tf-aws-control-990466748045-admin.aws_iam_policy.github' \
  'module.ih_tf_aws_control_990466748045.aws_iam_policy.github'
terraform state mv \
  'module.ih-tf-aws-control-990466748045-admin.aws_iam_role_policy_attachment.github' \
  'module.ih_tf_aws_control_990466748045.aws_iam_role_policy_attachment.github'
terraform state mv \
  'module.ih-tf-aws-control-990466748045-admin.aws_iam_role_policy_attachment.admin' \
  'module.ih_tf_aws_control_990466748045.aws_iam_role_policy_attachment.admin'
```

### Step 4: Import existing resources from 289256138624

```bash
# S3 bucket
terraform import \
  'module.state_bucket_990466748045.aws_s3_bucket.state-bucket' \
  infrahouse-aws-control-990466748045
terraform import \
  'module.state_bucket_990466748045.aws_s3_bucket_versioning.enabled' \
  infrahouse-aws-control-990466748045
terraform import \
  'module.state_bucket_990466748045.aws_s3_bucket_server_side_encryption_configuration.default' \
  infrahouse-aws-control-990466748045
terraform import \
  'module.state_bucket_990466748045.aws_s3_bucket_public_access_block.public_access' \
  infrahouse-aws-control-990466748045
terraform import \
  'module.state_bucket_990466748045.aws_s3_bucket_policy.state-bucke' \
  infrahouse-aws-control-990466748045

# State-manager role (in 289256138624)
terraform import \
  'module.ih_tf_aws_control_990466748045.module.state-manager.aws_iam_role.state-manager' \
  ih-tf-aws-control-state-manager
```

## Apply

### Step 5: Plan and apply locally

```bash
make plan
```

Expected plan:
- Roles updated (trust policies, tags, max_session_duration)
- GitHub policy updated (now includes allowed_arns)
- New DynamoDB table created (random suffix)
- New state-manager policies created + attached
- 5 SSM parameters created
- Cross-account policy + attachment **destroyed** (replaced by allowed_arns)
- S3 bucket tags updated

```bash
make apply
```

### Step 6: Update this repo's backend config

Read the new DynamoDB table name:
```bash
aws ssm get-parameter \
  --name "/terraform/aws-control/backend/lock_table" \
  --region us-west-1 \
  --query Parameter.Value --output text
```

Update `terraform.tf`:
```hcl
dynamodb_table = "<new-table-name>"  # was "infrahouse-terraform-state-locks"
```

Then:
```bash
terraform init -reconfigure
terraform plan  # should show no changes
```

Commit and push — CI/CD should work since role names didn't change.

## Cleanup aws-control-289256138624

### Step 7: Remove from aws-control-289256138624

```bash
cd /Users/aleks/code/infrahouse/aws-control-289256138624

# Remove state bucket from state
terraform state rm \
  'module.buckets["infrahouse-aws-control-990466748045"]'

# Remove state-manager from state
terraform state rm \
  'module.ih-tf-aws-control-state-manager'
```

Then:
- Remove `"infrahouse-aws-control-990466748045"` from `local.state_buckets`
- Remove the state-manager module block for 990466748045
- Apply to verify clean state

## Files Modified in aws-control

| File | Action |
|------|--------|
| `aws_iam_role.ih_tf_aws_control_990466748045.tf` | Rewrite: v3.6.1 + state-bucket + ci-cd-params |
| `aws_iam_policy.github_cross_account.tf` | **Delete** (replaced by allowed_arns) |

## Key Risks and Mitigations

- **CI/CD role names unchanged** — `ih-tf-aws-control-github`,
  `-admin`, `-state-manager` all keep their names. No workflow changes.
- **Cross-account permissions** — `allowed_arns` takes effect before
  the old cross-account policy is destroyed (terraform creates before
  destroying). No window without cross-account access.
- **State operations are local** — all state mv/import done locally
  before any apply. If something goes wrong, roles still exist in AWS.

## Verification

1. `terraform plan` — expect creates + updates + 2 destroys
   (cross-account policy + attachment)
2. `terraform apply` succeeds
3. `terraform init -reconfigure` with new DynamoDB table works
4. `terraform plan` shows no changes after backend migration
5. CI/CD works (open test PR, verify plan, merge, verify apply)
6. SSM parameters queryable in 990466748045