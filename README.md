# aws-control

Terraform configuration managing core AWS infrastructure in the
InfraHouse control account (990466748045).

## What it manages

* IAM users, roles, groups, and policies
* AWS SSO (Identity Center) configuration
* Backup infrastructure (Synology Glacier vault, S3 backup buckets)
* Cost alerts
* GitHub Actions OIDC integration for CI/CD

## Local Development

### Prerequisites

* Terraform (version in `.terraform-version`)
* AWS SSO access to the control account with `AWSAdministratorAccess`

### Authenticate via SSO

```bash
aws sso login --profile infrahouse-root-AWSAdministratorAccess
```

### Export credentials

Use `ih-aws` to export SSO credentials into your shell:

```bash
eval $(ih-aws --aws-profile infrahouse-root-AWSAdministratorAccess credentials -e)
```

### Run plan

```bash
make plan
```

This runs `terraform init` followed by `terraform plan`.

### Apply

```bash
make apply
```

Applies the saved plan from `tf.plan`.

## CI/CD

* **PR**: Lint, validate, plan, publish plan comment (`terraform-CI.yml`)
* **Merge**: Download saved plan, apply (`terraform-CD.yml`)
* Authentication uses OIDC (GitHub -> AWS IAM role `ih-tf-aws-control-github`)
