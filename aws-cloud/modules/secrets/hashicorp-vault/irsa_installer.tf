module "irsa_vault_installer" {
  count = var.db_cluster_resource_id != null ? 1 : 0
  depends_on = [local.dependency]
  source     = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version    = "6.2.1"
  name       = "${var.project}-vault-installer"
  policies = {
    "min_access" = aws_iam_policy.vault_installer_policy[0].arn
  }
  permissions_boundary = aws_iam_policy.vault_installer_policy[0].arn # application_permission_boundary.arn
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.vault_installer_namespace}:${var.vault_installer_serviceaccount}"]
    }
  }
}

# permissions boundary for the Vault Installer. vault-installer-policy.json
resource "aws_iam_policy" "vault_installer_policy" {
  # ?? for_each = var.db_cluster_resource_id != null ? { "enabled" = var.db_cluster_resource_id } : {}
  count = var.db_cluster_resource_id != null ? 1 : 0
  name  = "${var.project}-vault-installer-policy"
  path  = "/${var.tm_iam_prefix}/"
  policy = data.aws_iam_policy_document.vault_installer_policy[0].json
}

data "aws_iam_policy_document" "vault_installer_policy" {
  count = var.db_cluster_resource_id != null ? 1 : 0
  statement {
    sid    = "AllowRolesOnlyInPath"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/${var.tm_iam_prefix}/*"
    ]
  }
  statement {
    sid    = "AllowIamDbAuth"
    effect = "Allow"
    actions = [
      "rds-db:connect"
    ]
    resources = [
      "arn:aws:rds-db:${data.aws_region.current.region}:${local.aws_account_id}:dbuser:${var.db_cluster_resource_id}/${var.tm_iam_db_admin}"
    ]
  }
}
