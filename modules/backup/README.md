# Module for TwinDB Backup destination

The module creates necessary resources for a backup destination used in TwinDB backups.

Namely,

* AWS S3 bucket
* IAM user with credentials

The module configures permissions to allow the user read/write to the bucket.
