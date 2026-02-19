locals {
  sso_groups = {
    "AWSControlTowerAdmins" : "Admin rights to AWS Control Tower core and provisioned accounts"
    "AWSLogArchiveAdmins" : "Admin rights to log archive account"
    "AWSAccountFactory" : "Read-only access to account factory in AWS Service Catalog for end users"
    "AWSServiceCatalogAdmins" : "Admin rights to account factory in AWS Service Catalog"
    "AWSSecurityAuditPowerUsers" : "Power user access to all accounts for security audits"
    "AWSAuditAccountAdmins" : "Admin rights to cross-account audit account"
    "AWSSecurityAuditors" : "Read-only access to all accounts for security audits"
    "AWSLogArchiveViewers" : "Read-only access to log archive account"
  }

}
resource "aws_identitystore_group" "sso" {
  for_each          = local.sso_groups
  display_name      = each.key
  description       = each.value
  identity_store_id = local.identity_store_id
}
