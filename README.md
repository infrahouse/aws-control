# aws-control

The repository defines basic AWS configuration:

* IAM groups
* IAM users
* IAM roles
* IAM policies


# IAM

## Groups

The `aws-admin` group is for all human users. A member of this group can assume one of allowed IAM roles.


## Users

* `aleks` - me
* `tf_github` - a user that runs GitHub CI/CD

## Policies

* `TFAWSAdmin` - defines what roles can assume an entity that has this policy (`aws-admin`).
* `TFAdminForGitHub` - what a GitHub role can do.

## Roles

* `github-admin` - a role that anyone who wants to make a GitHub change

# DynamoDB

`terraform_locks` is a dynamodb table used for Terraform state locks.
