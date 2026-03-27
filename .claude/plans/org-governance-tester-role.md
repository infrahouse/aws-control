# Plan: Create Tester Role for terraform-aws-org-governance in 990466748045

## Context

`terraform-aws-org-governance` is a new module for centralized AWS Organizations governance,
deployed in the management account (990466748045). Its first use case is a Lambda that enforces
CloudWatch log retention across all member accounts by assuming `AWSControlTowerExecution`.

The module's CI tests need a tester role in the **management account** -- not in 303467602807
where other tester roles live. The 303467602807 tester role
([aws-control-303467602807#251](https://github.com/infrahouse/aws-control-303467602807/pull/251))
is useless for this module because it lacks org-level API access and cross-account assume
capabilities.

This is the first tester role in `aws-control` (990466748045). There is no existing
`module-tester-role` module here, so we need to create the role directly or adapt the pattern.

## Test Flow (what the tester role must support)

1. **Deploy** the module in 990466748045 (Lambda, IAM role, EventBridge, CloudWatch)
2. **Arrange**: Assume `AWSControlTowerExecution` into a member account, create a test
   CloudWatch log group with no retention
3. **Act**: Invoke the Lambda
4. **Assert**: Verify the test log group now has 365-day retention
5. **Teardown**: Delete the test log group, destroy the module resources

## Required Permissions

The tester role needs:

### AWS Organizations (read-only)
- `organizations:ListAccounts`
- `organizations:DescribeOrganization`

### STS (cross-account)
- `sts:AssumeRole` on `arn:aws:iam::*:role/AWSControlTowerExecution`
  (or scoped to `local.managed_account_ids`)

### Lambda (deploy + invoke)
- `lambda:*` (create, update, delete, invoke the module's Lambda)

### IAM (create module roles + policies)
- `iam:*` (create/delete the Lambda execution role and its policies)

### EventBridge (deploy scheduled trigger)
- `events:*` (create/delete the scheduled rule that triggers the Lambda)

### CloudWatch Logs (for the Lambda's own log group + test assertions)
- `logs:*` (create/delete log groups, set/verify retention)

### S3 (if the Lambda code is packaged in S3)
- `s3:*` on relevant buckets

### Alternatively: AdministratorAccess

Given the breadth of permissions and the pattern from 303467602807 (`grant_admin_permissions = true`
on all tester roles), the simplest approach is to grant `AdministratorAccess` to this tester role
as well. The role is scoped by its trust policy (GitHub Actions OIDC for the specific repo).

## Implementation (chosen: github-role module)

Uses `infrahouse/github-role/aws` v1.4.0 — a lightweight module that creates a single IAM role
with GitHub OIDC trust. Simpler than `gha-admin` (no extra state-manager/admin roles).

**File:** `aws_iam_role.org_governance_tester.tf`

```hcl
module "org_governance_tester" {
  source  = "infrahouse/github-role/aws"
  version = "1.4.0"

  gh_org_name          = "infrahouse"
  repo_name            = "terraform-aws-org-governance"
  role_name            = "org-governance-tester"
  max_session_duration = 43200

  depends_on = [module.github_connector]
}

resource "aws_iam_role_policy_attachment" "org_governance_tester_admin" {
  role       = module.org_governance_tester.github_role_name
  policy_arn = data.aws_iam_policy.administrator-access.arn
}
```

The `github-role` module internally looks up the OIDC provider via
`data.aws_iam_openid_connect_provider`, so `depends_on` on `module.github_connector`
ensures the provider exists first.

## terraform-aws-org-governance test configuration

Once the role exists, the module's test root needs:

**`tests/test_module.py`** -- test role ARN:
```
arn:aws:iam::990466748045:role/org-governance-tester
```

**`Makefile`** -- override the default test role:
```makefile
TEST_ROLE ?= arn:aws:iam::990466748045:role/org-governance-tester
```

## Verification

1. `terraform plan` shows the new role + policy attachment (2-3 resources)
2. Apply, then verify the role exists:
   `aws iam get-role --role-name org-governance-tester`
3. Verify GitHub Actions can assume it from the `terraform-aws-org-governance` repo
4. Verify SSO admin can assume it for local testing

## Open Questions

- Should we scope `sts:AssumeRole` on `AWSControlTowerExecution` to specific accounts instead of
  granting full `AdministratorAccess`? Full admin is the existing pattern, and the trust policy
  limits who can assume the role, but it's worth noting.
- Should the tester role in 303467602807 (from PR #251) be removed since it's not useful for this
  module?